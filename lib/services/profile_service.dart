import '../models/user_profile.dart';
import 'database_service.dart';

/// Helper service for loading, updating, and formatting UserProfile information.
class ProfileService {
  final DatabaseService _db = DatabaseService();

  Future<UserProfile> loadProfile() async {
    return _db.getUserProfile();
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _db.saveUserProfile(profile);
  }

  /// Provides rule-based fitness tip text matching the user's selected goal.
  static String getGoalTip(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.generalFitness:
        return "Aim for balanced workouts combining squats, push-ups, and planks 3x a week.";
      case FitnessGoal.strength:
        return "Build strength by focusing on progressive depth and form quality during squats and push-ups.";
      case FitnessGoal.mobility:
        return "Prioritize controlled movements and full range of motion in mobility poses.";
      case FitnessGoal.endurance:
        return "Incorporate higher repetition targets and sustained plank holds.";
      case FitnessGoal.flexibility:
        return "Improve flexibility and balance by maintaining stable alignment and holding static poses with deep breathing.";
    }
  }

  /// Human-readable label for experience level.
  static String experienceLabel(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return "Beginner";
      case ExperienceLevel.intermediate:
        return "Intermediate";
      case ExperienceLevel.advanced:
        return "Advanced";
    }
  }

  /// Human-readable label for fitness goal.
  static String goalLabel(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.generalFitness:
        return "General Fitness";
      case FitnessGoal.strength:
        return "Strength Training";
      case FitnessGoal.mobility:
        return "Mobility & Posture";
      case FitnessGoal.endurance:
        return "Stamina & Endurance";
      case FitnessGoal.flexibility:
        return "Flexibility & Balance";
    }
  }
}
