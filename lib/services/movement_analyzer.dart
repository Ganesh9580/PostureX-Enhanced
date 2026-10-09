import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'calibration_manager.dart';

/// Calculation result containing primary movement angle, secondary form angle,
/// and optional exercise-specific feedback warning.
class AnalysisFrame {
  final double primaryAngle;
  final double? secondaryAngle;
  final String? formWarning;

  const AnalysisFrame({
    required this.primaryAngle,
    this.secondaryAngle,
    this.formWarning,
  });
}

/// Specialized analysis engine evaluating landmark joint angles per exercise.
class MovementAnalyzer {
  static AnalysisFrame? analyzeFrame(
    ExerciseType exercise,
    Map<PoseLandmarkType, PoseLandmark?> landmarks,
    List<double> angleBuffer,
  ) {
    switch (exercise) {
      case ExerciseType.squat:
      case ExerciseType.jumpSquat:
        return _analyzeSquat(landmarks, angleBuffer);

      case ExerciseType.pushup:
        return _analyzePushup(landmarks, angleBuffer);

      case ExerciseType.bicepsCurl:
        return _analyzeBicepsCurl(landmarks, angleBuffer);

      case ExerciseType.shoulderPress:
        return _analyzeShoulderPress(landmarks, angleBuffer);

      case ExerciseType.lateralRaise:
      case ExerciseType.armRaise:
        return _analyzeLateralRaise(landmarks, angleBuffer);

      case ExerciseType.lunge:
      case ExerciseType.reverseLunge:
        return _analyzeLunge(landmarks, angleBuffer);

      case ExerciseType.calfRaise:
        return _analyzeCalfRaise(landmarks, angleBuffer);

      case ExerciseType.plank:
      case ExerciseType.sidePlank:
      case ExerciseType.gluteBridge:
      case ExerciseType.crunches:
      case ExerciseType.treePose:
      case ExerciseType.warriorTwo:
      case ExerciseType.chairPose:
      case ExerciseType.forwardBend:
      case ExerciseType.shoulderMobility:
        return _analyzeBodyLineHold(landmarks, angleBuffer);

      case ExerciseType.jumpingJack:
      case ExerciseType.highKnees:
      case ExerciseType.standingKneeRaises:
      case ExerciseType.mountainClimbers:
      case ExerciseType.burpees:
        return _analyzeGeneralJoint(landmarks, angleBuffer);
    }
  }

  static AnalysisFrame? _analyzeSquat(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];

    if (hip == null || knee == null || ankle == null) return null;

    final rawKnee = AngleCalculator.calculateAngle(hip, knee, ankle);
    final kneeAngle = AngleCalculator.smooth(angleBuffer, rawKnee);

    double? backAngle;
    String? warning;

    if (shoulder != null) {
      backAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);
      if (backAngle < 140) {
        warning = "Straighten your back";
      }
    }

    return AnalysisFrame(primaryAngle: kneeAngle, secondaryAngle: backAngle, formWarning: warning);
  }

  static AnalysisFrame? _analyzePushup(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || elbow == null || wrist == null) return null;

    final rawElbow = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final elbowAngle = AngleCalculator.smooth(angleBuffer, rawElbow);

    double? bodyLine;
    String? warning;

    if (hip != null && ankle != null) {
      bodyLine = AngleCalculator.calculateAngle(shoulder, hip, ankle);
      if (bodyLine < 145) {
        warning = "Keep your body straight";
      }
    }

    return AnalysisFrame(primaryAngle: elbowAngle, secondaryAngle: bodyLine, formWarning: warning);
  }

  static AnalysisFrame? _analyzeBicepsCurl(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];

    if (shoulder == null || elbow == null || wrist == null) return null;

    final rawElbow = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final elbowAngle = AngleCalculator.smooth(angleBuffer, rawElbow);

    return AnalysisFrame(primaryAngle: elbowAngle);
  }

  static AnalysisFrame? _analyzeShoulderPress(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];

    if (shoulder == null || elbow == null || wrist == null) return null;

    final rawElbow = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
    final elbowAngle = AngleCalculator.smooth(angleBuffer, rawElbow);

    return AnalysisFrame(primaryAngle: elbowAngle);
  }

  static AnalysisFrame? _analyzeLateralRaise(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];

    if (hip == null || shoulder == null || elbow == null) return null;

    final rawRaise = AngleCalculator.calculateAngle(hip, shoulder, elbow);
    final raiseAngle = AngleCalculator.smooth(angleBuffer, rawRaise);

    return AnalysisFrame(primaryAngle: raiseAngle);
  }

  static AnalysisFrame? _analyzeLunge(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (hip == null || knee == null || ankle == null) return null;

    final rawKnee = AngleCalculator.calculateAngle(hip, knee, ankle);
    final kneeAngle = AngleCalculator.smooth(angleBuffer, rawKnee);

    return AnalysisFrame(primaryAngle: kneeAngle);
  }

  static AnalysisFrame? _analyzeCalfRaise(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];
    final foot = landmarks[PoseLandmarkType.leftHeel] ?? landmarks[PoseLandmarkType.rightHeel];

    if (knee == null || ankle == null) return null;

    final rawAngle = AngleCalculator.calculateAngle(knee, ankle, foot ?? knee);
    final smoothed = AngleCalculator.smooth(angleBuffer, rawAngle);

    return AnalysisFrame(primaryAngle: smoothed);
  }

  static AnalysisFrame? _analyzeBodyLineHold(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || hip == null || ankle == null) return null;

    final rawLine = AngleCalculator.calculateAngle(shoulder, hip, ankle);
    final bodyLineAngle = AngleCalculator.smooth(angleBuffer, rawLine);

    String? warning;
    if (bodyLineAngle < 145) {
      warning = "Align body in a straight line";
    }

    return AnalysisFrame(primaryAngle: bodyLineAngle, formWarning: warning);
  }

  static AnalysisFrame? _analyzeGeneralJoint(Map<PoseLandmarkType, PoseLandmark?> landmarks, List<double> angleBuffer) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];

    if (shoulder == null || hip == null || knee == null) return null;

    final rawAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);
    final smoothed = AngleCalculator.smooth(angleBuffer, rawAngle);

    return AnalysisFrame(primaryAngle: smoothed);
  }
}
