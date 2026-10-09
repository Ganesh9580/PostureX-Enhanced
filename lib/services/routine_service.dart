import '../models/workout_routine.dart';
import '../models/user_profile.dart';
import 'database_service.dart';

class RoutineService {
  final DatabaseService _db = DatabaseService();

  Future<List<WorkoutRoutine>> loadAllRoutines() async {
    return _db.getWorkoutRoutines();
  }

  Future<void> saveCustomRoutine(WorkoutRoutine routine) async {
    await _db.saveWorkoutRoutine(routine);
  }

  Future<void> deleteCustomRoutine(String id) async {
    await _db.deleteWorkoutRoutine(id);
  }

  /// Recommends routines based on the user's primary fitness goal and experience level.
  static List<WorkoutRoutine> getRecommendedRoutines(
    List<WorkoutRoutine> all,
    UserProfile profile,
  ) {
    return all.where((r) {
      final goalMatch = r.fitnessGoal == profile.fitnessGoal || r.fitnessGoal == FitnessGoal.generalFitness;
      final diffMatch = r.difficulty == profile.experienceLevel || r.difficulty == ExperienceLevel.beginner;
      return goalMatch || diffMatch;
    }).toList();
  }
}
