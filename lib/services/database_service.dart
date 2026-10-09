import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_profile.dart';
import '../models/personal_record.dart';
import '../models/workout_routine.dart';

/// Handles local persistence of points, premium unlock status, user profile,
/// personal records, session history, and workout routines using SQLite (sqflite).
class DatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'posture_coach.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Tables(db);
        await _createV3Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await _createV2Tables(db);
  }

  if (oldVersion < 3) {
    await _createV3Tables(db);
  }
},
onOpen: (db) async {
  // Repair missing tables in databases created by older app versions.
  await _createV2Tables(db);
  await _createV3Tables(db);
},
    );
  }

  static Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE app_state (
        id INTEGER PRIMARY KEY,
        total_points INTEGER NOT NULL DEFAULT 0,
        premium_unlocked INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise TEXT NOT NULL,
        result_value REAL NOT NULL,
        avg_score REAL,
        points_earned INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.insert('app_state', {'id': 1, 'total_points': 0, 'premium_unlocked': 0});
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        nickname TEXT,
        age INTEGER,
        height REAL,
        weight REAL,
        experience_level TEXT NOT NULL,
        fitness_goal TEXT NOT NULL,
        preferred_duration TEXT NOT NULL,
        unit TEXT NOT NULL,
        profile_image_path TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS personal_records (
        exercise TEXT PRIMARY KEY,
        max_result REAL NOT NULL,
        best_score REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    final existingProfile = await db.query('user_profile', where: 'id = 1');
    if (existingProfile.isEmpty) {
      await db.insert('user_profile', const UserProfile().toMap());
    }
  }

  static Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_routines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        fitness_goal TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        exercises_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    final existingRoutines = await db.query('workout_routines');
    if (existingRoutines.isEmpty) {
      await _insertPreloadedRoutines(db);
    }
  }

  static Future<void> _insertPreloadedRoutines(Database db) async {
    final now = DateTime.now().toIso8601String();

    final preloaded = [
      {
        'id': 'routine_full_body_flow',
        'name': 'Beginner Full Body Flow',
        'description': 'Balanced introduction targeting squats, biceps, calf raises, and standing knees.',
        'difficulty': 'beginner',
        'fitness_goal': 'generalFitness',
        'estimated_minutes': 15,
        'is_custom': 0,
        'created_at': now,
        'exercises_json': jsonEncode([
          {'exercise_id': 'squat', 'exercise_name': 'Squats', 'target_reps': 10, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'biceps_curl', 'exercise_name': 'Biceps Curls', 'target_reps': 10, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'calf_raise', 'exercise_name': 'Calf Raises', 'target_reps': 12, 'target_hold_seconds': 0.0, 'sets': 2, 'rest_seconds': 20},
          {'exercise_id': 'standing_knee_raises', 'exercise_name': 'Standing Knee Raises', 'target_reps': 12, 'target_hold_seconds': 0.0, 'sets': 2, 'rest_seconds': 20},
        ]),
      },
      {
        'id': 'routine_core_posture',
        'name': 'Core Stability & Posture Pro',
        'description': 'Focused isometric hold flow designed to strengthen abdominal wall and back posture.',
        'difficulty': 'intermediate',
        'fitness_goal': 'mobility',
        'estimated_minutes': 15,
        'is_custom': 0,
        'created_at': now,
        'exercises_json': jsonEncode([
          {'exercise_id': 'plank', 'exercise_name': 'Plank', 'target_reps': 0, 'target_hold_seconds': 20.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'chair_pose', 'exercise_name': 'Chair Pose', 'target_reps': 0, 'target_hold_seconds': 15.0, 'sets': 2, 'rest_seconds': 25},
          {'exercise_id': 'tree_pose', 'exercise_name': 'Tree Pose', 'target_reps': 0, 'target_hold_seconds': 15.0, 'sets': 2, 'rest_seconds': 20},
          {'exercise_id': 'forward_bend', 'exercise_name': 'Standing Forward Bend', 'target_reps': 0, 'target_hold_seconds': 15.0, 'sets': 2, 'rest_seconds': 20},
        ]),
      },
      {
        'id': 'routine_upper_strength',
        'name': 'Upper Body Strength Builder',
        'description': 'High-intensity push-ups, lateral raises, and shoulder presses for upper body power.',
        'difficulty': 'intermediate',
        'fitness_goal': 'strength',
        'estimated_minutes': 20,
        'is_custom': 0,
        'created_at': now,
        'exercises_json': jsonEncode([
          {'exercise_id': 'pushup', 'exercise_name': 'Push-ups', 'target_reps': 8, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 45},
          {'exercise_id': 'lateral_raise', 'exercise_name': 'Lateral Raises', 'target_reps': 10, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'shoulder_press', 'exercise_name': 'Shoulder Press', 'target_reps': 10, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'biceps_curl', 'exercise_name': 'Biceps Curls', 'target_reps': 12, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
        ]),
      },
      {
        'id': 'routine_cardio_blast',
        'name': 'High-Intensity Cardio Blast',
        'description': 'Fast-paced high knees, jumping jacks, and jump squats to maximize endurance.',
        'difficulty': 'advanced',
        'fitness_goal': 'endurance',
        'estimated_minutes': 20,
        'is_custom': 0,
        'created_at': now,
        'exercises_json': jsonEncode([
          {'exercise_id': 'high_knees', 'exercise_name': 'High Knees', 'target_reps': 20, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'jumping_jack', 'exercise_name': 'Jumping Jacks', 'target_reps': 15, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 30},
          {'exercise_id': 'jump_squat', 'exercise_name': 'Jump Squats', 'target_reps': 10, 'target_hold_seconds': 0.0, 'sets': 3, 'rest_seconds': 40},
        ]),
      },
    ];

    for (final r in preloaded) {
      await db.insert('workout_routines', r);
    }
  }

  // --- App State & Points ---

  Future<int> getTotalPoints() async {
    final db = await database;
    final rows = await db.query('app_state', where: 'id = 1');
    if (rows.isEmpty) return 0;
    return rows.first['total_points'] as int;
  }

  Future<bool> isPremiumUnlocked() async {
    final db = await database;
    final rows = await db.query('app_state', where: 'id = 1');
    if (rows.isEmpty) return false;
    return (rows.first['premium_unlocked'] as int) == 1;
  }

  Future<int> addPoints(int amount) async {
    final db = await database;
    final current = await getTotalPoints();
    final newTotal = current + amount;
    await db.update('app_state', {'total_points': newTotal}, where: 'id = 1');
    return newTotal;
  }

  Future<void> setPremiumUnlocked() async {
    final db = await database;
    await db.update('app_state', {'premium_unlocked': 1}, where: 'id = 1');
  }

  // --- User Profile ---

  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1');
    if (rows.isEmpty) {
      const defaultProfile = UserProfile();
      await db.insert('user_profile', defaultProfile.toMap());
      return defaultProfile;
    }
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Workout Routines ---

  Future<List<WorkoutRoutine>> getWorkoutRoutines() async {
    final db = await database;
    final rows = await db.query('workout_routines', orderBy: 'is_custom DESC, name ASC');
    return rows.map((r) => WorkoutRoutine.fromMap(r)).toList();
  }

  Future<void> saveWorkoutRoutine(WorkoutRoutine routine) async {
    final db = await database;
    await db.insert(
      'workout_routines',
      routine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWorkoutRoutine(String id) async {
    final db = await database;
    await db.delete('workout_routines', where: 'id = ? AND is_custom = 1', whereArgs: [id]);
  }

  // --- Sessions & Personal Records ---

  Future<void> saveSession({
    required String exercise,
    required double resultValue,
    double? avgScore,
    required int pointsEarned,
  }) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    await db.insert('sessions', {
      'exercise': exercise,
      'result_value': resultValue,
      'avg_score': avgScore,
      'points_earned': pointsEarned,
      'timestamp': timestamp,
    });

    await _updatePersonalRecord(
      db: db,
      exercise: exercise,
      resultValue: resultValue,
      score: avgScore ?? 10.0,
      timestamp: timestamp,
    );
  }

  Future<void> _updatePersonalRecord({
    required Database db,
    required String exercise,
    required double resultValue,
    required double score,
    required String timestamp,
  }) async {
    final rows = await db.query('personal_records', where: 'exercise = ?', whereArgs: [exercise]);
    if (rows.isEmpty) {
      await db.insert('personal_records', {
        'exercise': exercise,
        'max_result': resultValue,
        'best_score': score,
        'updated_at': timestamp,
      });
    } else {
      final currentMax = (rows.first['max_result'] as num).toDouble();
      final currentBestScore = (rows.first['best_score'] as num).toDouble();

      final newMax = resultValue > currentMax ? resultValue : currentMax;
      final newScore = score > currentBestScore ? score : currentBestScore;

      await db.update(
        'personal_records',
        {
          'max_result': newMax,
          'best_score': newScore,
          'updated_at': timestamp,
        },
        where: 'exercise = ?',
        whereArgs: [exercise],
      );
    }
  }

  Future<List<Map<String, Object?>>> getSessionHistory({int limit = 50}) async {
    final db = await database;
    return db.query('sessions', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<List<PersonalRecord>> getPersonalRecords() async {
    final db = await database;
    final rows = await db.query('personal_records', orderBy: 'max_result DESC');
    return rows.map((r) => PersonalRecord.fromMap(r)).toList();
  }

  // --- Real-time Dashboard Aggregations ---

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final sessions = await db.query('sessions', orderBy: 'timestamp DESC');
    final points = await getTotalPoints();
    final profile = await getUserProfile();
    final prs = await getPersonalRecords();

    int totalSessions = sessions.length;
    int totalReps = 0;
    double totalHoldSeconds = 0;

    List<int> weeklyActivity = List.filled(7, 0);
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    for (final s in sessions) {
      final exercise = s['exercise'] as String;
      final val = (s['result_value'] as num).toDouble();
      final time = DateTime.tryParse(s['timestamp'] as String);

      if (exercise.toLowerCase().contains('plank') || exercise.toLowerCase().contains('pose')) {
        totalHoldSeconds += val;
      } else {
        totalReps += val.round();
      }

      if (time != null && time.isAfter(sevenDaysAgo)) {
        final dayIndex = time.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          weeklyActivity[dayIndex]++;
        }
      }
    }

    return {
      'totalSessions': totalSessions,
      'totalReps': totalReps,
      'totalHoldSeconds': totalHoldSeconds,
      'totalPoints': points,
      'profile': profile,
      'personalRecords': prs,
      'weeklyActivity': weeklyActivity,
      'recentSessions': sessions.take(5).toList(),
    };
  }
}