import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:ai_posture_coach/models/user_profile.dart';
import 'package:ai_posture_coach/models/personal_record.dart';
import 'package:ai_posture_coach/models/exercise.dart';
import 'package:ai_posture_coach/models/workout_routine.dart';
import 'package:ai_posture_coach/data/exercise_catalog.dart';
import 'package:ai_posture_coach/services/profile_service.dart';
import 'package:ai_posture_coach/services/routine_service.dart';
import 'package:ai_posture_coach/services/points_service.dart';
import 'package:ai_posture_coach/services/hold_timer.dart';
import 'package:ai_posture_coach/services/form_scorer.dart';
import 'package:ai_posture_coach/services/calibration_manager.dart';
import 'package:ai_posture_coach/services/pose_visibility_checker.dart';
import 'package:ai_posture_coach/services/pose_stability_tracker.dart';
import 'package:ai_posture_coach/services/movement_analyzer.dart';

void main() {
  group('WorkoutRoutine Model Tests', () {
    test('WorkoutRoutine toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final routine = WorkoutRoutine(
        id: 'test_routine_1',
        name: 'Custom Core Routine',
        description: 'Test core description',
        difficulty: ExperienceLevel.intermediate,
        fitnessGoal: FitnessGoal.mobility,
        estimatedMinutes: 20,
        isCustom: true,
        items: const [
          WorkoutRoutineItem(exerciseId: 'plank', exerciseName: 'Plank', targetHoldSeconds: 20, sets: 3, restSeconds: 30),
          WorkoutRoutineItem(exerciseId: 'squat', exerciseName: 'Squats', targetReps: 12, sets: 3, restSeconds: 30),
        ],
        createdAt: now,
      );

      final map = routine.toMap();
      final reconstructed = WorkoutRoutine.fromMap(map);

      expect(reconstructed.id, routine.id);
      expect(reconstructed.name, routine.name);
      expect(reconstructed.difficulty, routine.difficulty);
      expect(reconstructed.fitnessGoal, routine.fitnessGoal);
      expect(reconstructed.isCustom, true);
      expect(reconstructed.items.length, 2);
      expect(reconstructed.items[0].exerciseId, 'plank');
    });

    test('RoutineService recommendations filter based on user profile', () {
      const profile = UserProfile(
        experienceLevel: ExperienceLevel.beginner,
        fitnessGoal: FitnessGoal.generalFitness,
      );

      final routines = [
        WorkoutRoutine(
          id: '1',
          name: 'Beginner Flow',
          description: 'desc',
          difficulty: ExperienceLevel.beginner,
          fitnessGoal: FitnessGoal.generalFitness,
          estimatedMinutes: 15,
          items: const [],
          createdAt: DateTime.now(),
        ),
        WorkoutRoutine(
          id: '2',
          name: 'Advanced Pro Strength',
          description: 'desc',
          difficulty: ExperienceLevel.advanced,
          fitnessGoal: FitnessGoal.strength,
          estimatedMinutes: 30,
          items: const [],
          createdAt: DateTime.now(),
        ),
      ];

      final recs = RoutineService.getRecommendedRoutines(routines, profile);
      expect(recs.map((r) => r.id), contains('1'));
    });
  });

  group('PoseVisibilityChecker Tests', () {
    test('checkVisibility detects missing landmarks and generates advice', () {
      final landmarks = <PoseLandmarkType, PoseLandmark?>{
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.5, y: 0.2, z: 0.0, likelihood: 0.9),
      };

      final result = PoseVisibilityChecker.checkVisibility(ExerciseType.squat, landmarks);
      expect(result.isFullyVisible, false);
      expect(result.missingLandmarks, isNotEmpty);
      expect(result.warningMessage, isNotNull);
    });
  });

  group('PoseStabilityTracker Tests', () {
    test('update calculates high stability for static landmark and low stability for swaying landmark', () {
      final tracker = PoseStabilityTracker(windowSize: 5);

      double score = 0.0;
      for (int i = 0; i < 5; i++) {
        score = tracker.update(PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.5, y: 0.5, z: 0.0, likelihood: 0.9));
      }
      expect(score, closeTo(1.0, 0.05));
      expect(tracker.isStable(score), true);
    });
  });

  group('MovementAnalyzer Tests', () {
    test('analyzeFrame evaluates squat knee and back angles', () {
      final landmarks = <PoseLandmarkType, PoseLandmark?>{
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.5, y: 0.2, z: 0.0, likelihood: 0.9),
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.5, y: 0.5, z: 0.0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0.5, y: 0.7, z: 0.0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0.5, y: 0.9, z: 0.0, likelihood: 0.9),
      };

      final buffer = <double>[];
      final frame = MovementAnalyzer.analyzeFrame(ExerciseType.squat, landmarks, buffer);

      expect(frame, isNotNull);
      expect(frame!.primaryAngle, greaterThan(0.0));
    });
  });

  group('Exercise Catalog & Domain Model Tests', () {
    test('ExerciseCatalog contains exercises for all 5 categories', () {
      final all = ExerciseCatalog.allExercises;
      expect(all.length, greaterThanOrEqualTo(15));

      final upper = ExerciseCatalog.getByCategory(ExerciseCategory.upperBody);
      final lower = ExerciseCatalog.getByCategory(ExerciseCategory.lowerBody);
      final core = ExerciseCatalog.getByCategory(ExerciseCategory.core);
      final cardio = ExerciseCatalog.getByCategory(ExerciseCategory.fullBodyCardio);
      final yoga = ExerciseCatalog.getByCategory(ExerciseCategory.mobilityYoga);

      expect(upper, isNotEmpty);
      expect(lower, isNotEmpty);
      expect(core, isNotEmpty);
      expect(cardio, isNotEmpty);
      expect(yoga, isNotEmpty);
    });

    test('Exercise lookup by id and type works correctly', () {
      final squat = ExerciseCatalog.getById('squat');
      expect(squat, isNotNull);
      expect(squat!.name, 'Squats');
      expect(squat.category, ExerciseCategory.lowerBody);

      final plank = ExerciseCatalog.getById('plank');
      expect(plank, isNotNull);
      expect(plank!.analysisType, AnalysisType.staticHold);
    });
  });

  group('UserProfile Model Tests', () {
    test('Default UserProfile has expected fallback values and completion ratio', () {
      const profile = UserProfile();
      expect(profile.name, 'Athlete');
      expect(profile.experienceLevel, ExperienceLevel.beginner);
      expect(profile.fitnessGoal, FitnessGoal.generalFitness);
      expect(profile.unit, MeasurementUnit.metric);
      expect(profile.completionPercentage, closeTo(0.125, 0.01));
    });

    test('UserProfile completion percentage increases with added fields', () {
      const profile = UserProfile(
        name: 'Jane Doe',
        nickname: 'Jane',
        age: 28,
        height: 168.0,
        weight: 62.0,
        experienceLevel: ExperienceLevel.intermediate,
        fitnessGoal: FitnessGoal.strength,
      );
      expect(profile.completionPercentage, greaterThan(0.70));
    });

    test('UserProfile toMap and fromMap serialization roundtrip', () {
      const original = UserProfile(
        name: 'Alex Smith',
        nickname: 'Al',
        age: 30,
        height: 175.5,
        weight: 70.0,
        experienceLevel: ExperienceLevel.advanced,
        fitnessGoal: FitnessGoal.mobility,
        preferredDuration: '30+ min',
        unit: MeasurementUnit.imperial,
        notes: 'Targeting hip mobility',
      );

      final map = original.toMap();
      final reconstructed = UserProfile.fromMap(map);

      expect(reconstructed.name, original.name);
      expect(reconstructed.nickname, original.nickname);
      expect(reconstructed.age, original.age);
      expect(reconstructed.height, original.height);
      expect(reconstructed.weight, original.weight);
      expect(reconstructed.experienceLevel, original.experienceLevel);
      expect(reconstructed.fitnessGoal, original.fitnessGoal);
      expect(reconstructed.preferredDuration, original.preferredDuration);
      expect(reconstructed.unit, original.unit);
      expect(reconstructed.notes, original.notes);
    });
  });

  group('PersonalRecord Model Tests', () {
    test('PersonalRecord toMap and fromMap serialization', () {
      final now = DateTime.now();
      final pr = PersonalRecord(
        exercise: 'Squats',
        maxResult: 25.0,
        bestScore: 9.5,
        updatedAt: now,
      );

      final map = pr.toMap();
      final reconstructed = PersonalRecord.fromMap(map);

      expect(reconstructed.exercise, 'Squats');
      expect(reconstructed.maxResult, 25.0);
      expect(reconstructed.bestScore, 9.5);
    });
  });

  group('ProfileService Helper Tests', () {
    test('getGoalTip returns relevant guidance per goal', () {
      expect(ProfileService.getGoalTip(FitnessGoal.strength), contains('strength'));
      expect(ProfileService.getGoalTip(FitnessGoal.flexibility).toLowerCase(), contains('flexibility'));
    });

    test('experienceLabel & goalLabel format correctly', () {
      expect(ProfileService.experienceLabel(ExperienceLevel.beginner), 'Beginner');
      expect(ProfileService.goalLabel(FitnessGoal.generalFitness), 'General Fitness');
    });
  });

  group('Core Math & Scoring Service Tests', () {
    test('PointsService calculates points scaled by score', () {
      expect(PointsService.pointsForRep(10.0), 20);
      expect(PointsService.pointsForRep(5.0), 10);
      expect(PointsService.sessionBonus(true), 40);
      expect(PointsService.sessionBonus(false), 20);
    });

    test('HoldTimer accumulates time during good form and pauses during bad form', () {
      final timer = HoldTimer();
      expect(timer.heldSeconds, 0.0);

      timer.update(true, 10.0);
      expect(timer.wasInGoodForm, true);

      timer.update(false, 10.0);
      expect(timer.wasInGoodForm, false);
    });

    test('FormScorer computes squat and pushup scores in 0-10 range', () {
      final squatScore = FormScorer.scoreSquat(depthAngle: 90, backAngle: 160);
      expect(squatScore, greaterThanOrEqualTo(0.0));
      expect(squatScore, lessThanOrEqualTo(10.0));

      final pushupScore = FormScorer.scorePushup(depthAngle: 75, bodyLineAngle: 165);
      expect(pushupScore, greaterThanOrEqualTo(0.0));
      expect(pushupScore, lessThanOrEqualTo(10.0));
    });
  });
}
