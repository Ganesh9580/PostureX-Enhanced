import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';

enum ExerciseType {
  squat,
  pushup,
  plank,
  jumpingJack,
  jumpSquat,
  bicepsCurl,
  shoulderPress,
  lateralRaise,
  armRaise,
  lunge,
  reverseLunge,
  calfRaise,
  gluteBridge,
  sidePlank,
  crunches,
  standingKneeRaises,
  highKnees,
  mountainClimbers,
  burpees,
  treePose,
  warriorTwo,
  chairPose,
  forwardBend,
  shoulderMobility,
}

/// Handles the "match the shadow guide" calibration step before real
/// tracking begins. The user must hold a target starting pose for a
/// number of consecutive frames before calibration is confirmed.
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
      case ExerciseType.jumpingJack:
      case ExerciseType.jumpSquat:
      case ExerciseType.bicepsCurl:
      case ExerciseType.shoulderPress:
      case ExerciseType.lateralRaise:
      case ExerciseType.armRaise:
      case ExerciseType.lunge:
      case ExerciseType.reverseLunge:
      case ExerciseType.calfRaise:
      case ExerciseType.standingKneeRaises:
      case ExerciseType.highKnees:
      case ExerciseType.treePose:
      case ExerciseType.warriorTwo:
      case ExerciseType.chairPose:
      case ExerciseType.forwardBend:
      case ExerciseType.shoulderMobility:
        matches = _checkStandingStart(landmarks);
        break;
      case ExerciseType.pushup:
      case ExerciseType.mountainClimbers:
      case ExerciseType.burpees:
        matches = _checkPushupStart(landmarks);
        break;
      case ExerciseType.plank:
      case ExerciseType.sidePlank:
      case ExerciseType.gluteBridge:
      case ExerciseType.crunches:
        matches = _checkPlankStart(landmarks);
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

  bool _checkStandingStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || hip == null || knee == null || ankle == null) return false;

    final kneeAngle = AngleCalculator.calculateAngle(hip, knee, ankle);
    final backAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);

    return kneeAngle >= 145 && backAngle >= 140;
  }

  bool _checkPushupStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) return false;

    final elbowAngle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final bodyLineAngle = AngleCalculator.calculateAngle(shoulder, hip, ankle);

    return elbowAngle >= 145 && bodyLineAngle >= 145;
  }

  bool _checkPlankStart(Map<PoseLandmarkType, PoseLandmark?> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) return false;

    final elbowAngle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final bodyLineAngle = AngleCalculator.calculateAngle(shoulder, hip, ankle);

    return elbowAngle >= 50 && elbowAngle <= 130 && bodyLineAngle >= 140;
  }

  void reset() {
    _matchFrameCount = 0;
    _isCalibrated = false;
  }
}