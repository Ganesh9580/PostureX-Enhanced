/// Experience levels supported by PostureX.
enum ExperienceLevel { beginner, intermediate, advanced }

/// Fitness goals supported by PostureX.
enum FitnessGoal { generalFitness, strength, mobility, endurance, flexibility }

/// Measurement units supported by PostureX.
enum MeasurementUnit { metric, imperial }

/// Data model representing local user profile preferences and physical metrics.
class UserProfile {
  final String name;
  final String? nickname;
  final int? age;
  final double? height; // stored in cm if metric, inches if imperial
  final double? weight; // stored in kg if metric, lbs if imperial
  final ExperienceLevel experienceLevel;
  final FitnessGoal fitnessGoal;
  final String preferredDuration; // e.g. "15-20 min"
  final MeasurementUnit unit;
  final String? profileImagePath;
  final String? notes;

  const UserProfile({
    this.name = "Athlete",
    this.nickname,
    this.age,
    this.height,
    this.weight,
    this.experienceLevel = ExperienceLevel.beginner,
    this.fitnessGoal = FitnessGoal.generalFitness,
    this.preferredDuration = "15-20 min",
    this.unit = MeasurementUnit.metric,
    this.profileImagePath,
    this.notes,
  });

  /// Calculates profile completion percentage (0.0 to 1.0).
  double get completionPercentage {
    int filled = 0;
    const totalFields = 8;

    if (name.isNotEmpty && name != "Athlete") filled++;
    if (nickname != null && nickname!.trim().isNotEmpty) filled++;
    if (age != null && age! > 0) filled++;
    if (height != null && height! > 0) filled++;
    if (weight != null && weight! > 0) filled++;
    if (profileImagePath != null && profileImagePath!.isNotEmpty) filled++;
    if (notes != null && notes!.trim().isNotEmpty) filled++;
    filled++; // default experience/goal always set

    return (filled / totalFields).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'name': name,
      'nickname': nickname,
      'age': age,
      'height': height,
      'weight': weight,
      'experience_level': experienceLevel.name,
      'fitness_goal': fitnessGoal.name,
      'preferred_duration': preferredDuration,
      'unit': unit.name,
      'profile_image_path': profileImagePath,
      'notes': notes,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] as String? ?? "Athlete",
      nickname: map['nickname'] as String?,
      age: map['age'] as int?,
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.name == map['experience_level'],
        orElse: () => ExperienceLevel.beginner,
      ),
      fitnessGoal: FitnessGoal.values.firstWhere(
        (g) => g.name == map['fitness_goal'],
        orElse: () => FitnessGoal.generalFitness,
      ),
      preferredDuration: map['preferred_duration'] as String? ?? "15-20 min",
      unit: MeasurementUnit.values.firstWhere(
        (u) => u.name == map['unit'],
        orElse: () => MeasurementUnit.metric,
      ),
      profileImagePath: map['profile_image_path'] as String?,
      notes: map['notes'] as String?,
    );
  }

  UserProfile copyWith({
    String? name,
    String? nickname,
    int? age,
    double? height,
    double? weight,
    ExperienceLevel? experienceLevel,
    FitnessGoal? fitnessGoal,
    String? preferredDuration,
    MeasurementUnit? unit,
    String? profileImagePath,
    String? notes,
  }) {
    return UserProfile(
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      preferredDuration: preferredDuration ?? this.preferredDuration,
      unit: unit ?? this.unit,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      notes: notes ?? this.notes,
    );
  }
}
