/// Model representing a personal record for a specific exercise.
class PersonalRecord {
  final String exercise;
  final double maxResult; // reps or held seconds
  final double bestScore;
  final DateTime updatedAt;

  const PersonalRecord({
    required this.exercise,
    required this.maxResult,
    required this.bestScore,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'exercise': exercise,
      'max_result': maxResult,
      'best_score': bestScore,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PersonalRecord.fromMap(Map<String, dynamic> map) {
    return PersonalRecord(
      exercise: map['exercise'] as String,
      maxResult: (map['max_result'] as num).toDouble(),
      bestScore: (map['best_score'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
