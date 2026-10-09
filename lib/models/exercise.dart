import '../services/calibration_manager.dart';

/// Categories for organizing the exercise library.
enum ExerciseCategory { upperBody, lowerBody, core, fullBodyCardio, mobilityYoga }

/// Difficulty levels.
enum ExerciseDifficulty { beginner, intermediate, advanced }

/// Camera setup orientations.
enum CameraPosition { sideView, frontView }

/// Type of movement analysis (repetition counting vs static hold tracking).
enum AnalysisType { repetition, staticHold }

/// Model representing a structured exercise in PostureX.
class Exercise {
  final String id;
  final String name;
  final ExerciseCategory category;
  final ExerciseDifficulty difficulty;
  final CameraPosition cameraPosition;
  final AnalysisType analysisType;
  final List<String> targetMuscles;
  final String description;
  final List<String> instructions;
  final String cameraSetupGuide;
  final bool isPremium;
  final int defaultGoal; // reps or seconds
  final ExerciseType exerciseType;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.cameraPosition,
    required this.analysisType,
    required this.targetMuscles,
    required this.description,
    required this.instructions,
    required this.cameraSetupGuide,
    required this.isPremium,
    required this.defaultGoal,
    required this.exerciseType,
  });

  String get categoryLabel {
    switch (category) {
      case ExerciseCategory.upperBody:
        return "Upper Body";
      case ExerciseCategory.lowerBody:
        return "Lower Body";
      case ExerciseCategory.core:
        return "Core";
      case ExerciseCategory.fullBodyCardio:
        return "Full Body & Cardio";
      case ExerciseCategory.mobilityYoga:
        return "Mobility & Yoga";
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return "Beginner";
      case ExerciseDifficulty.intermediate:
        return "Intermediate";
      case ExerciseDifficulty.advanced:
        return "Advanced";
    }
  }

  String get cameraPositionLabel {
    switch (cameraPosition) {
      case CameraPosition.sideView:
        return "Side-on View (2m distance)";
      case CameraPosition.frontView:
        return "Facing Camera (2m distance)";
    }
  }
}
