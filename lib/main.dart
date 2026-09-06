import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'services/angle_calculator.dart';
import 'services/rep_detector.dart';
import 'services/calibration_manager.dart';
import 'services/voice_feedback_service.dart';
import 'services/form_scorer.dart';
import 'services/hold_timer.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Posture Coach',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const PoseTrackingScreen(),
    );
  }
}

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

class PoseTrackingScreen extends StatefulWidget {
  const PoseTrackingScreen({super.key});

  @override
  State<PoseTrackingScreen> createState() => _PoseTrackingScreenState();
}

class _PoseTrackingScreenState extends State<PoseTrackingScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  late final PoseDetector _poseDetector;
  List<Pose> _poses = [];
  bool _isDetecting = false;
  CameraDescription? _selectedCamera;

  ExerciseType _selectedExercise = ExerciseType.squat;

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

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _repDetector = _buildRepDetector(_selectedExercise);
    _voice.init();
    _initCamera();
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
    });
  }

  void _onExerciseChanged(ExerciseType? newExercise) {
    if (newExercise == null) return;
    setState(() {
      _selectedExercise = newExercise;
    });
    _resetSession();
  }

  Future<void> _initCamera() async {
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

  /// Runs the primary-angle calculation, rep-state update, form checking,
  /// and scoring for whichever exercise is currently selected. Returns the
  /// primary angle for display, or null if required landmarks aren't visible.
  double? _handleActiveTracking(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final cfg = exerciseConfigs[_selectedExercise]!;

    PoseLandmark? p1, p2, p3; // primary angle: p1-p2-p3, angle at p2
    PoseLandmark? s1, s2, s3; // secondary (form) angle: s1-s2-s3, angle at s2
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

    // Mid-rep form check, only meaningful during the "down" phase
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
        // Form broke at some point during this rep — don't count it, don't
        // score it, and don't speak a number. The "Stop" correction already
        // covered it; speaking anything more here is what caused the
        // confusing overlapping audio before. Show a brief visual banner
        // instead, since text can't collide with speech.
        _showBanner("Rep not counted — fix your form and try again");
      } else {
        _repCount++;
        final secondaryForScore = _minSecondaryAngleThisRep == 200 ? 150.0 : _minSecondaryAngleThisRep;
        final score = _selectedExercise == ExerciseType.squat
            ? FormScorer.scoreSquat(depthAngle: depthAtRepEnd ?? 90, backAngle: secondaryForScore)
            : FormScorer.scorePushup(depthAngle: depthAtRepEnd ?? 75, bodyLineAngle: secondaryForScore);
        _scores.add(score);
        _voice.speak("$_repCount", force: true, minGapMs: 0);

        if (_repCount >= cfg.goal) {
          _sessionComplete = true;
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

  /// Plank uses a hold-timer instead of rep counting. Body-line angle alone
  /// can't distinguish an elevated plank from lying flat on the ground
  /// (both look like a straight line to the camera), so this also tracks
  /// chest height (average of shoulder+hip vertical position) against a
  /// baseline captured right after calibration — a significant drop means
  /// the user has collapsed, not just that the angle changed slightly.
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
    final dropFromBaseline = chestHeight - _chestHeightBaseline!; // larger = lower on screen = collapsed

    final angleOk = bodyLineAngle > 155 && elbowAngle >= 50 && elbowAngle <= 130;
    final notCollapsed = dropFromBaseline < 60; // pixel-ish threshold in normalized landmark units
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
        title: const Text("AI Posture Coach"),
        backgroundColor: Colors.teal[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: DropdownButton<ExerciseType>(
                value: _selectedExercise,
                dropdownColor: Colors.teal[800],
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                items: exerciseConfigs.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label)))
                    .toList(),
                onChanged: _onExerciseChanged,
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
                    top: 130,
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
                            ? "${cfg.label} Held: ${_holdTimer.heldSeconds.toStringAsFixed(1)}s / ${cfg.goal}s   (${_plankFormBroken ? 'paused' : 'holding'})"
                            : "${cfg.label} Reps: $_repCount / ${cfg.goal}   (state: ${_repDetector.state})",
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
                            ElevatedButton(
                              onPressed: _resetSession,
                              child: const Text("Try Again"),
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

// Draws a translucent outline of the target starting pose for calibration.
// Rotated to match the phone's PHYSICAL orientation (even though the app's
// software UI stays locked in portrait) so the guide visually lines up with
// how the camera content actually appears when the phone is turned sideways
// — e.g. for push-ups, which need a landscape-style framing of the body.
class ShadowGuidePainter extends CustomPainter {
  final ExerciseType exercise;
  final DeviceOrientation deviceOrientation;
  ShadowGuidePainter({required this.exercise, required this.deviceOrientation});

  double get _rotationRadians {
    switch (deviceOrientation) {
      case DeviceOrientation.landscapeLeft:
        return -1.5707963; // -90°
      case DeviceOrientation.landscapeRight:
        return 1.5707963; // 90°
      case DeviceOrientation.portraitDown:
        return 3.14159265; // 180°
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
      // Diagonal, top-to-bottom figure that fits naturally within a normal
      // portrait frame — no need to physically rotate the phone. This is
      // roughly how a phone propped nearby would actually see someone in
      // push-up position on the floor.
      final headX = w * 0.22, headY = h * 0.16;
      final shoulderX = w * 0.30, shoulderY = h * 0.24;
      final hipX = w * 0.52, hipY = h * 0.52;
      final ankleX = w * 0.78, ankleY = h * 0.84;

      canvas.drawCircle(Offset(headX, headY), h * 0.04, paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), paint);
      canvas.drawLine(Offset(hipX, hipY), Offset(ankleX, ankleY), paint);
      // Straight arm down to the floor
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(shoulderX - w * 0.03, shoulderY + h * 0.16), paint);
    } else {
      // Plank: same diagonal top-to-bottom framing, with a bent forearm
      // instead of a straight arm.
      final headX = w * 0.22, headY = h * 0.16;
      final shoulderX = w * 0.30, shoulderY = h * 0.24;
      final hipX = w * 0.52, hipY = h * 0.52;
      final ankleX = w * 0.78, ankleY = h * 0.84;

      canvas.drawCircle(Offset(headX, headY), h * 0.04, paint);
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), paint);
      canvas.drawLine(Offset(hipX, hipY), Offset(ankleX, ankleY), paint);
      // Bent forearm to the floor (elbow ~90°)
      canvas.drawLine(Offset(shoulderX, shoulderY), Offset(shoulderX - w * 0.02, shoulderY + h * 0.10), paint);
      canvas.drawLine(Offset(shoulderX - w * 0.02, shoulderY + h * 0.10), Offset(shoulderX - w * 0.09, shoulderY + h * 0.11), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShadowGuidePainter oldDelegate) =>
      oldDelegate.exercise != exercise || oldDelegate.deviceOrientation != deviceOrientation;
}

// Draws the skeleton (landmarks + connecting lines) on top of the camera preview
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