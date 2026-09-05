import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'services/angle_calculator.dart';
import 'services/rep_detector.dart';
import 'services/calibration_manager.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — this is an exercise-tracking app, landscape isn't a
  // realistic use case, and supporting it reliably needs more device-specific
  // tuning than is worth the complexity here.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
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
  final List<double> _kneeAngleBuffer = [];
  double _currentKneeAngle = 0;
  int _repCount = 0;
  final RepDetector _squatDetector = RepDetector(
    downThreshold: 110, // knee angle below this = "down" (squatting)
    upThreshold: 160,   // knee angle above this = "up" (standing)
    framesToConfirm: 5,
  );
  final CalibrationManager _calibration = CalibrationManager(framesToConfirm: 20);

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _initCamera();
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
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        final poses = await _poseDetector.processImage(inputImage);

        double kneeAngle = _currentKneeAngle;
        if (poses.isNotEmpty) {
          final landmarks = poses.first.landmarks;
          final hip = landmarks[PoseLandmarkType.leftHip];
          final knee = landmarks[PoseLandmarkType.leftKnee];
          final ankle = landmarks[PoseLandmarkType.leftAnkle];

          if (hip != null && knee != null && ankle != null) {
            final rawAngle = AngleCalculator.calculateAngle(hip, knee, ankle);
            kneeAngle = AngleCalculator.smooth(_kneeAngleBuffer, rawAngle);

            if (!_calibration.isCalibrated) {
              _calibration.checkSquatStart(landmarks);
            } else {
              final repCompleted = _squatDetector.update(kneeAngle);
              if (repCompleted) {
                _repCount++;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _poses = poses;
            _currentKneeAngle = kneeAngle;
          });
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
    }

    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _selectedCamera!;
    final sensorOrientation = camera.sensorOrientation;

    // Fixed rotation based on the camera sensor only — correct and reliable
    // for portrait use, which is this app's only supported orientation.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFrontCamera = _selectedCamera?.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AI Posture Coach — Pose Test"),
        backgroundColor: Colors.teal[800],
      ),
      body: _isCameraReady && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Android's front camera preview is already mirrored natively —
                // we do NOT flip this widget. Only the skeleton overlay below is
                // flipped (in SkeletonPainter) to match what's already on screen.
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
                    painter: ShadowGuidePainter(),
                    size: Size.infinite,
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text(
                      "Landmarks detected: ${_poses.isNotEmpty ? _poses.first.landmarks.length : 0}",
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text(
                      "Left Knee Angle: ${_currentKneeAngle.toStringAsFixed(1)}°",
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
                          const Text(
                            "Match the outline: stand straight, full body visible",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 14),
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
                    top: 88,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.black54,
                      child: Text(
                        "Squat Reps: $_repCount   (state: ${_squatDetector.state})",
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: Colors.teal[700],
                      onPressed: () {
                        setState(() {
                          _repCount = 0;
                          _squatDetector.reset();
                          _calibration.reset();
                        });
                      },
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
    );
  }

  // The raw camera preview size is fixed to the sensor's natural landscape
  // orientation, so width/height are swapped to match portrait display.
  Size _getImageSize() {
    final previewSize = _controller!.value.previewSize!;
    return Size(previewSize.height, previewSize.width);
  }
}

// Draws a translucent dashed outline of the target standing pose, shown
// during calibration so the user knows exactly how to position themselves.
class ShadowGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    final headY = h * 0.18;
    final shoulderY = h * 0.26;
    final hipY = h * 0.52;
    final ankleY = h * 0.88;

    // Head
    canvas.drawCircle(Offset(cx, headY), h * 0.045, paint);
    // Torso
    canvas.drawLine(Offset(cx, shoulderY), Offset(cx, hipY), paint);
    // Arms (relaxed at sides)
    canvas.drawLine(Offset(cx, shoulderY), Offset(cx - w * 0.12, hipY * 0.95), paint);
    canvas.drawLine(Offset(cx, shoulderY), Offset(cx + w * 0.12, hipY * 0.95), paint);
    // Legs (straight, standing)
    canvas.drawLine(Offset(cx, hipY), Offset(cx - w * 0.06, ankleY), paint);
    canvas.drawLine(Offset(cx, hipY), Offset(cx + w * 0.06, ankleY), paint);
  }

  @override
  bool shouldRepaint(covariant ShadowGuidePainter oldDelegate) => false;
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
      // Flip the X coordinate to match the mirrored preview.
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