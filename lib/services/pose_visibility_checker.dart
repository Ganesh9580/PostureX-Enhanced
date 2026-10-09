import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/calibration_manager.dart';

/// Result of a landmark visibility and framing check.
class VisibilityResult {
  final bool isFullyVisible;
  final List<PoseLandmarkType> missingLandmarks;
  final String? warningMessage;

  const VisibilityResult({
    required this.isFullyVisible,
    required this.missingLandmarks,
    this.warningMessage,
  });
}

/// Validates landmark confidence and framing before running joint-angle calculations.
class PoseVisibilityChecker {
  static const double defaultMinLikelihood = 0.50;

  /// Checks if all required landmarks for the specified exercise are present
  /// with sufficient confidence (likelihood >= minLikelihood).
  static VisibilityResult checkVisibility(
    ExerciseType exercise,
    Map<PoseLandmarkType, PoseLandmark?> landmarks, {
    double minLikelihood = defaultMinLikelihood,
  }) {
    final requiredTypes = _getRequiredLandmarks(exercise);
    final missing = <PoseLandmarkType>[];

    for (final type in requiredTypes) {
      final landmark = landmarks[type];
      if (landmark == null || landmark.likelihood < minLikelihood) {
        missing.add(type);
      }
    }

    if (missing.isEmpty) {
      return const VisibilityResult(isFullyVisible: true, missingLandmarks: []);
    }

    final message = _generateFramingAdvice(missing);
    return VisibilityResult(
      isFullyVisible: false,
      missingLandmarks: missing,
      warningMessage: message,
    );
  }

  static List<PoseLandmarkType> _getRequiredLandmarks(ExerciseType exercise) {
    switch (exercise) {
      case ExerciseType.squat:
      case ExerciseType.lunge:
      case ExerciseType.reverseLunge:
      case ExerciseType.calfRaise:
      case ExerciseType.jumpSquat:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        ];
      case ExerciseType.pushup:
      case ExerciseType.mountainClimbers:
      case ExerciseType.burpees:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftAnkle,
        ];
      case ExerciseType.plank:
      case ExerciseType.sidePlank:
      case ExerciseType.gluteBridge:
      case ExerciseType.crunches:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftAnkle,
        ];
      case ExerciseType.jumpingJack:
      case ExerciseType.highKnees:
      case ExerciseType.standingKneeRaises:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
      case ExerciseType.bicepsCurl:
      case ExerciseType.shoulderPress:
      case ExerciseType.lateralRaise:
      case ExerciseType.armRaise:
      case ExerciseType.shoulderMobility:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftHip,
        ];
      case ExerciseType.treePose:
      case ExerciseType.warriorTwo:
      case ExerciseType.chairPose:
      case ExerciseType.forwardBend:
        return [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        ];
    }
  }

  static String _generateFramingAdvice(List<PoseLandmarkType> missing) {
    bool hasLower = missing.any((t) => t == PoseLandmarkType.leftAnkle || t == PoseLandmarkType.rightAnkle || t == PoseLandmarkType.leftKnee || t == PoseLandmarkType.rightKnee);
    bool hasUpper = missing.any((t) => t == PoseLandmarkType.leftWrist || t == PoseLandmarkType.rightWrist || t == PoseLandmarkType.leftShoulder);

    if (hasLower && hasUpper) {
      return "Step back — full body not visible in frame";
    } else if (hasLower) {
      return "Tilt camera down — feet/legs cut off";
    } else if (hasUpper) {
      return "Step back — upper body/wrists out of frame";
    } else {
      return "Adjust camera position — key joints obscured";
    }
  }
}
