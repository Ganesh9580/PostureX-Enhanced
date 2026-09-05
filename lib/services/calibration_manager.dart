import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';

/// Handles the "match the shadow guide" calibration step before real
/// tracking begins. The user must hold a target starting pose for a
/// number of consecutive frames before calibration is confirmed —
/// same approach validated in the web prototype.
class CalibrationManager {
  final int framesToConfirm;
  int _matchFrameCount = 0;
  bool _isCalibrated = false;

  CalibrationManager({this.framesToConfirm = 20});

  bool get isCalibrated => _isCalibrated;
  int get matchFrameCount => _matchFrameCount;
  int get framesNeeded => framesToConfirm;

  /// Checks if the squat starting position (standing, knee mostly straight)
  /// is matched. Returns true the moment calibration is newly confirmed.
  bool checkSquatStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    if (_isCalibrated) return false;

    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final knee = landmarks[PoseLandmarkType.leftKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      _matchFrameCount = 0;
      return false;
    }

    final kneeAngle = AngleCalculator.calculateAngle(hip, knee, ankle);
    final backAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);

    final matches = kneeAngle >= 160 && backAngle >= 150;

    if (matches) {
      _matchFrameCount++;
    } else {
      _matchFrameCount = 0;
    }

    if (_matchFrameCount >= framesToConfirm) {
      _isCalibrated = true;
      return true;
    }
    return false;
  }

  void reset() {
    _matchFrameCount = 0;
    _isCalibrated = false;
  }
}