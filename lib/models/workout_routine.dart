import 'dart:convert';
import 'user_profile.dart';

/// Single exercise item within a workout routine.
class WorkoutRoutineItem {
  final String exerciseId;
  final String exerciseName;
  final int targetReps;
  final double targetHoldSeconds;
  final int sets;
  final int restSeconds;

  const WorkoutRoutineItem({
    required this.exerciseId,
    required this.exerciseName,
    this.targetReps = 10,
    this.targetHoldSeconds = 20.0,
    this.sets = 3,
    this.restSeconds = 30,
  });

  Map<String, dynamic> toMap() {
    return {
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'target_reps': targetReps,
      'target_hold_seconds': targetHoldSeconds,
      'sets': sets,
      'rest_seconds': restSeconds,
    };
  }

  factory WorkoutRoutineItem.fromMap(Map<String, dynamic> map) {
    return WorkoutRoutineItem(
      exerciseId: map['exercise_id'] as String,
      exerciseName: map['exercise_name'] as String,
      targetReps: map['target_reps'] as int? ?? 10,
      targetHoldSeconds: (map['target_hold_seconds'] as num?)?.toDouble() ?? 20.0,
      sets: map['sets'] as int? ?? 3,
      restSeconds: map['rest_seconds'] as int? ?? 30,
    );
  }
}

/// Data model representing a workout routine sequence.
class WorkoutRoutine {
  final String id;
  final String name;
  final String description;
  final ExperienceLevel difficulty;
  final FitnessGoal fitnessGoal;
  final int estimatedMinutes;
  final bool isCustom;
  final List<WorkoutRoutineItem> items;
  final DateTime createdAt;

  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.fitnessGoal,
    required this.estimatedMinutes,
    this.isCustom = false,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty.name,
      'fitness_goal': fitnessGoal.name,
      'estimated_minutes': estimatedMinutes,
      'is_custom': isCustom ? 1 : 0,
      'exercises_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WorkoutRoutine.fromMap(Map<String, dynamic> map) {
    final jsonStr = map['exercises_json'] as String;
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final items = jsonList.map((j) => WorkoutRoutineItem.fromMap(j as Map<String, dynamic>)).toList();

    return WorkoutRoutine(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      difficulty: ExperienceLevel.values.firstWhere(
        (e) => e.name == map['difficulty'],
        orElse: () => ExperienceLevel.beginner,
      ),
      fitnessGoal: FitnessGoal.values.firstWhere(
        (g) => g.name == map['fitness_goal'],
        orElse: () => FitnessGoal.generalFitness,
      ),
      estimatedMinutes: map['estimated_minutes'] as int? ?? 15,
      isCustom: (map['is_custom'] as int?) == 1,
      items: items,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? "") ?? DateTime.now(),
    );
  }
}
