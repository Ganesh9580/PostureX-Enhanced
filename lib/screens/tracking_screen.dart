import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/angle_calculator.dart';
import '../services/rep_detector.dart';
import '../services/calibration_manager.dart';
import '../services/voice_feedback_service.dart';
import '../services/form_scorer.dart';
import '../services/hold_timer.dart';
import '../services/database_service.dart';
import '../services/points_service.dart';

List<CameraDescription> cameras = [];

// Per-exercise configuration: thresholds, goal, and ideal target angles.
class ExerciseConfig {
  final String label;
  final int goal; // reps for squat/pushup, seconds for plank
  final double downThreshold;
  final double upThreshold;
  final bool isHoldBased;

  const ExerciseConfig({
    required this.label,
    required this.goal,
    this.downThreshold = 0,
    this.upThreshold = 0,
    this.isHoldBased = false,
  });
}

const Map<ExerciseType, ExerciseConfig> exerciseConfigs = {
  ExerciseType.squat: ExerciseConfig(label: "Squats", goal: 10, downThreshold: 110, upThreshold: 160),
  ExerciseType.pushup: ExerciseConfig(label: "Push-ups", goal: 5, downThreshold: 95, upThreshold: 155),
  ExerciseType.plank: ExerciseConfig(label: "Plank", goal: 20, isHoldBased: true),
};

class TrackingScreen extends StatefulWidget {
  final ExerciseType exercise;
  const TrackingScreen({super.key, required this.exercise});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  late final PoseDetector _poseDetector;
  List<Pose> _poses = [];
  bool _isDetecting = false;
  CameraDescription? _selectedCamera;

  late final ExerciseType _selectedExercise; // fixed for this screen instance

  final List<double> _angleBuffer = [];
  double _currentAngle = 0;
  int _repCount = 0;
  late RepDetector _repDetector;
  final CalibrationManager _calibration = CalibrationManager(framesToConfirm: 20);
  final VoiceFeedbackService _voice = VoiceFeedbackService();

  bool _formWarnedThisRep = false;
  double _minSecondaryAngleThisRep = 200;
  final List<double> _scores = [];
  bool _sessionComplete = false;
  String? _statusBanner;
  Timer? _bannerTimer;

  // Plank-specific state
  final HoldTimer _holdTimer = HoldTimer();
  double? _chestHeightBaseline;
  bool _plankFormBroken = false;

  // Points & persistence
  final DatabaseService _db = DatabaseService();
  int _totalPoints = 0;
  bool _isPremiumUnlocked = false;
  int _sessionPointsEarned = 0;

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.exercise;
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _repDetector = _buildRepDetector(_selectedExercise);
    _voice.init();
    _loadPoints();
    _initCamera();
  }

  Future<void> _loadPoints() async {
    final points = await _db.getTotalPoints();
    final unlocked = await _db.isPremiumUnlocked();
    if (mounted) {
      setState(() {
        _totalPoints = points;
        _isPremiumUnlocked = unlocked;
      });
    }
  }

  Future<void> _awardPoints(int amount) async {
    final oldTotal = _totalPoints;
    final newTotal = await _db.addPoints(amount);
    if (!mounted) return;
    setState(() {
      _totalPoints = newTotal;
      _sessionPointsEarned += amount;
    });

    if (!_isPremiumUnlocked && PointsService.crossesUnlockThreshold(oldTotal, newTotal)) {
      await _db.setPremiumUnlocked();
      setState(() {
        _isPremiumUnlocked = true;
      });
      _voice.speak(
        "Congratulations! You've unlocked the Premium Module!",
        force: true,
        minGapMs: 0,
      );
    }
  }

  void _showBanner(String message) {
    _bannerTimer?.cancel();
    setState(() {
      _statusBanner = message;
    });
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _statusBanner = null);
    });
  }

  RepDetector _buildRepDetector(ExerciseType exercise) {
    final cfg = exerciseConfigs[exercise]!;
    return RepDetector(downThreshold: cfg.downThreshold, upThreshold: cfg.upThreshold, framesToConfirm: 5);
  }

  void _resetSession() {
    setState(() {
      _repCount = 0;
      _repDetector = _buildRepDetector(_selectedExercise);
      _calibration.reset();
      _formWarnedThisRep = false;
      _minSecondaryAngleThisRep = 200;
      _scores.clear();
      _sessionComplete = false;
      _holdTimer.reset();
      _chestHeightBaseline = null;
      _plankFormBroken = false;
      _sessionPointsEarned = 0;
    });
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      cameras = await availableCameras();
    }
    if (cameras.isEmpty) {
      debugPrint("No cameras found on this device.");
      return;
    }

    _selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _sessionComplete) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        final poses = await _poseDetector.processImage(inputImage);

        double currentAngle = _currentAngle;
        if (poses.isNotEmpty) {
          final landmarks = poses.first.landmarks;

          if (!_calibration.isCalibrated) {
            final justCalibrated = _calibration.checkStart(_selectedExercise, landmarks);
            if (justCalibrated) {
              _voice.speak("Position matched. Start!", force: true, minGapMs: 0);
            }
          } else {
            currentAngle = _selectedExercise == ExerciseType.plank
                ? _handlePlankTracking(landmarks) ?? currentAngle
                : _handleActiveTracking(landmarks) ?? currentAngle;
          }
        }

        if (mounted) {
          setState(() {
            _poses = poses;
            _currentAngle = currentAngle;
          });
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
    }

    _isDetecting = false;
  }

  double? _handleActiveTracking(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final cfg = exerciseConfigs[_selectedExercise]!;

    PoseLandmark? p1, p2, p3;
    PoseLandmark? s1, s2, s3;
    String formWarningMessage;

    if (_selectedExercise == ExerciseType.squat) {
      p1 = landmarks[PoseLandmarkType.leftHip];
      p2 = landmarks[PoseLandmarkType.leftKnee];
      p3 = landmarks[PoseLandmarkType.leftAnkle];
      s1 = landmarks[PoseLandmarkType.leftShoulder];
      s2 = landmarks[PoseLandmarkType.leftHip];
      s3 = landmarks[PoseLandmarkType.leftKnee];
      formWarningMessage = "Stop. Straighten your back.";
    } else {
      p1 = landmarks[PoseLandmarkType.leftShoulder];
      p2 = landmarks[PoseLandmarkType.leftElbow];
      p3 = landmarks[PoseLandmarkType.leftWrist];
      s1 = landmarks[PoseLandmarkType.leftShoulder];
      s2 = landmarks[PoseLandmarkType.leftHip];
      s3 = landmarks[PoseLandmarkType.leftAnkle];
      formWarningMessage = "Stop. Keep your body straight.";
    }

    if (p1 == null || p2 == null || p3 == null) return null;

    final rawAngle = AngleCalculator.calculateAngle(p1, p2, p3);
    final angle = AngleCalculator.smooth(_angleBuffer, rawAngle);

    if (s1 != null && s2 != null && s3 != null && _repDetector.state == "down") {
      final secondaryAngle = AngleCalculator.calculateAngle(s1, s2, s3);
      _minSecondaryAngleThisRep =
          secondaryAngle < _minSecondaryAngleThisRep ? secondaryAngle : _minSecondaryAngleThisRep;

      final formBreakThreshold = _selectedExercise == ExerciseType.squat ? 145.0 : 150.0;
      if (secondaryAngle < formBreakThreshold && !_formWarnedThisRep) {
        _voice.speak(formWarningMessage, force: true, minGapMs: 1200);
        _formWarnedThisRep = true;
      }
    }

    final wasDown = _repDetector.state == "down";
    final depthAtRepEnd = _repDetector.extremeAngle;
    final wasWarnedThisRep = _formWarnedThisRep;
    final repCompleted = _repDetector.update(angle);

    if (wasDown == false && _repDetector.state == "down") {
      _formWarnedThisRep = false;
      _minSecondaryAngleThisRep = 200;
    }

    if (repCompleted) {
      if (wasWarnedThisRep) {
        _showBanner("Rep not counted — fix your form and try again");
      } else {
        _repCount++;
        final secondaryForScore = _minSecondaryAngleThisRep == 200 ? 150.0 : _minSecondaryAngleThisRep;
        final score = _selectedExercise == ExerciseType.squat
            ? FormScorer.scoreSquat(depthAngle: depthAtRepEnd ?? 90, backAngle: secondaryForScore)
            : FormScorer.scorePushup(depthAngle: depthAtRepEnd ?? 75, bodyLineAngle: secondaryForScore);
        _scores.add(score);
        _voice.speak("$_repCount", force: true, minGapMs: 0);
        _awardPoints(PointsService.pointsForRep(score));

        if (_repCount >= cfg.goal) {
          _sessionComplete = true;
          _awardPoints(PointsService.sessionBonus(false));
          final avgScore = _scores.reduce((a, b) => a + b) / _scores.length;
          _db.saveSession(
            exercise: cfg.label,
            resultValue: _repCount.toDouble(),
            avgScore: avgScore,
            pointsEarned: _sessionPointsEarned + PointsService.sessionBonus(false),
          );
          Future.delayed(const Duration(milliseconds: 900), () {
            _voice.speak(
              "Session complete! You finished all ${cfg.goal} reps. Excellent work!",
              force: true,
              minGapMs: 0,
            );
          });
        }
      }
    }

    return angle;
  }

  double? _handlePlankTracking(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final cfg = exerciseConfigs[ExerciseType.plank]!;
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) {
      return null;
    }

    final bodyLineAngle = AngleCalculator.calculateAngle(shoulder, hip, ankle);
    final elbowAngle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);

    final chestHeight = (shoulder.y + hip.y) / 2;
    _chestHeightBaseline ??= chestHeight;
    final dropFromBaseline = chestHeight - _chestHeightBaseline!;

    final angleOk = bodyLineAngle > 155 && elbowAngle >= 50 && elbowAngle <= 130;
    final notCollapsed = dropFromBaseline < 60;
    final isGoodForm = angleOk && notCollapsed;

    if (!isGoodForm && !_plankFormBroken) {
      _plankFormBroken = true;
      final message = !notCollapsed
          ? "Form broken. You've dropped too low — lift back up."
          : "Form broken. Straighten your body to continue.";
      _voice.speak(message, force: true, minGapMs: 2000);
    } else if (isGoodForm && _plankFormBroken) {
      _plankFormBroken = false;
    }

    final reachedGoal = _holdTimer.update(isGoodForm, cfg.goal.toDouble());
    if (reachedGoal) {
      _sessionComplete = true;
      final bonus = PointsService.sessionBonus(true);
      _awardPoints(bonus);
      _db.saveSession(
        exercise: cfg.label,
        resultValue: _holdTimer.heldSeconds,
        avgScore: null,
        pointsEarned: bonus,
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        _voice.speak(
          "Session complete! You held a perfect plank. Excellent work!",
          force: true,
          minGapMs: 0,
        );
      });
    }

    return bodyLineAngle;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _selectedCamera!;
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    _voice.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrontCamera = _selectedCamera?.lensDirection == CameraLensDirection.front;
    final cfg = exerciseConfigs[_selectedExercise]!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(cfg.label),
        backgroundColor: Colors.teal[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$_totalPoints",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isCameraReady && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                CustomPaint(
                  painter: SkeletonPainter(
                    poses: _poses,
                    imageSize: _getImageSize(),
                    mirror: isFrontCamera,
                  ),
                ),
                if (!_calibration.isCalibrated)
                  CustomPaint(
                    painter: ShadowGuidePainter(
                      exercise: _selectedExercise,
                      deviceOrientation: _controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp,
                    ),
                    size: Size.infinite,
                  ),
                if (_statusBanner != null)
                  Positioned(
                    top: 90,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusBanner!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text(
                      "Angle: ${_currentAngle.toStringAsFixed(1)}°",
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                if (!_calibration.isCalibrated)
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.tealAccent, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedExercise == ExerciseType.squat
                                ? "Match the outline: stand straight, full body visible"
                                : _selectedExercise == ExerciseType.pushup
                                    ? "Match the outline: top push-up position, side-on view"
                                    : "Match the outline: forearm plank position, side-on view",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _calibration.matchFrameCount / _calibration.framesNeeded,
                            backgroundColor: Colors.white24,
                            color: Colors.tealAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_calibration.isCalibrated) ...[
                  Positioned(
                    top: 50,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.black54,
                      child: Text(
                        cfg.isHoldBased
                            ? "Held: ${_holdTimer.heldSeconds.toStringAsFixed(1)}s / ${cfg.goal}s   (${_plankFormBroken ? 'paused' : 'holding'})"
                            : "Reps: $_repCount / ${cfg.goal}   (state: ${_repDetector.state})",
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_scores.isNotEmpty)
                    Positioned(
                      top: 88,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.black54,
                        child: Text(
                          "Avg Score: ${(_scores.reduce((a, b) => a + b) / _scores.length).toStringAsFixed(1)}   Best: ${_scores.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: Colors.teal[700],
                      onPressed: _resetSession,
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ],
                if (_sessionComplete)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              "Session Complete!",
                              style: TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cfg.isHoldBased
                                  ? "You held a perfect ${cfg.label} for ${cfg.goal} seconds."
                                  : "You finished all ${cfg.goal} ${cfg.label}.\nAvg Score: ${_scores.isEmpty ? '-' : (_scores.reduce((a, b) => a + b) / _scores.length).toStringAsFixed(1)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+ $_sessionPointsEarned points earned",
                                style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_isPremiumUnlocked)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  "Premium Module Unlocked!",
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: _resetSession,
                                  child: const Text("Try Again"),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                  child: const Text("Back to Home"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
    );
  }

  Size _getImageSize() {
    final previewSize = _controller!.value.previewSize!;
    return Size(previewSize.height, previewSize.width);
  }
}

class ShadowGuidePainter extends CustomPainter {
  final ExerciseType exercise;
  final DeviceOrientation deviceOrientation;
  ShadowGuidePainter({required this.exercise, required this.deviceOrientation});

  double get _rotationRadians {
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
        return -1.5707963;
      case DeviceOrientation.landscapeRight:
        return 1.5707963;
      case DeviceOrientation.portraitDown:
        return 3.14159265;
      case DeviceOrientation.portraitUp:
        return 0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_rotationRadians);
    canvas.translate(-size.width / 2, -size.height / 2);

    final paint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final markerPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    if (exercise == ExerciseType.squat) {
      final cx = w * 0.5;
      final headY = h * 0.18;
      final shoulderY = h * 0.26;
      final hipY = h * 0.52;
      final ankleY = h * 0.88;

      canvas.drawCircle(Offset(cx, headY), h * 0.045, paint);
      canvas.drawLine(Offset(cx, shoulderY), Offset(cx, hipY), paint);
      canvas.drawLine(Offset(cx, shoulderY), Offset(cx - w * 0.12, hipY * 0.95), paint);
      canvas.drawLine(Offset(cx, shoulderY), Offset(cx + w * 0.12, hipY * 0.95), paint);
      canvas.drawLine(Offset(cx, hipY), Offset(cx - w * 0.06, ankleY), paint);
      canvas.drawLine(Offset(cx, hipY), Offset(cx + w * 0.06, ankleY), paint);
    } else if (exercise == ExerciseType.pushup) {
      final headX = w * 0.20, headY = h * 0.13;
      final shoulderX = w * 0.27, shoulderY = h * 0.20;
      final hipX = w * 0.50, hipY = h * 0.48;
      final ankleX = w * 0.76, ankleY = h * 0.80;
      final handX = shoulderX - w * 0.01, handY = shoulderY + h * 0.20;

      canvas.drawCircle(Offset(headX, headY), h * 0.035, paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), paint);
      canvas.drawLine(Offset(hipX, hipY), Offset(ankleX, ankleY), paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(handX, handY), paint);
      canvas.drawCircle(Offset(handX, handY), 5, markerPaint);
      canvas.drawCircle(Offset(ankleX, ankleY), 5, markerPaint);
    } else {
      final headX = w * 0.20, headY = h * 0.13;
      final shoulderX = w * 0.27, shoulderY = h * 0.20;
      final hipX = w * 0.50, hipY = h * 0.48;
      final ankleX = w * 0.76, ankleY = h * 0.80;
      final elbowX = shoulderX - w * 0.005, elbowY = shoulderY + h * 0.11;
      final forearmX = elbowX - w * 0.07, forearmY = elbowY + h * 0.01;

      canvas.drawCircle(Offset(headX, headY), h * 0.035, paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), paint);
      canvas.drawLine(Offset(hipX, hipY), Offset(ankleX, ankleY), paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(elbowX, elbowY), paint);
      canvas.drawLine(Offset(elbowX, elbowY), Offset(forearmX, forearmY), paint);
      canvas.drawCircle(Offset(ankleX, ankleY), 5, markerPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShadowGuidePainter oldDelegate) =>
      oldDelegate.exercise != exercise || oldDelegate.deviceOrientation != deviceOrientation;
}

class SkeletonPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool mirror;

  SkeletonPainter({required this.poses, required this.imageSize, required this.mirror});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.7)
      ..strokeWidth = 3;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    Offset transformPoint(double x, double y) {
      final px = x * scaleX;
      final py = y * scaleY;
      return Offset(mirror ? size.width - px : px, py);
    }

    for (final pose in poses) {
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, transformPoint);
      _drawLine(canvas, linePaint, pose, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, transformPoint);

      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(transformPoint(landmark.x, landmark.y), 5, dotPaint);
      }
    }
  }

  void _drawLine(Canvas canvas, Paint paint, Pose pose, PoseLandmarkType type1, PoseLandmarkType type2, Offset Function(double, double) transform) {
    final l1 = pose.landmarks[type1];
    final l2 = pose.landmarks[type2];
    if (l1 != null && l2 != null) {
      canvas.drawLine(transform(l1.x, l1.y), transform(l2.x, l2.y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) => true;
}