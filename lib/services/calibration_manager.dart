import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';

enum ExerciseType { squat, pushup }

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

  /// Checks if the starting position for the given exercise is matched.
  /// Returns true the moment calibration is newly confirmed.
  bool checkStart(ExerciseType exercise, Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    if (_isCalibrated) return false;

    bool matches;
    switch (exercise) {
      case ExerciseType.squat:
        matches = _checkSquatStart(landmarks);
        break;
      case ExerciseType.pushup:
        matches = _checkPushupStart(landmarks);
        break;
    }

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

  bool _checkSquatStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final knee = landmarks[PoseLandmarkType.leftKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || hip == null || knee == null || ankle == null) return false;

    final kneeAngle = AngleCalculator.calculateAngle(hip, knee, ankle);
    final backAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);

    return kneeAngle >= 160 && backAngle >= 150;
  }

  bool _checkPushupStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist];
    final hip = landmarks[PoseLandmarkType.leftHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) return false;

    final elbowAngle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final bodyLineAngle = AngleCalculator.calculateAngle(shoulder, hip, ankle);

    return elbowAngle >= 155 && bodyLineAngle >= 155;
  }

  void reset() {
    _matchFrameCount = 0;
    _isCalibrated = false;
  }
}