import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
        if (mounted) {
          setState(() {
            _poses = poses;
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