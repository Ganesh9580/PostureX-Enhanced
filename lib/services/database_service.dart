import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Handles local persistence of points, premium-unlock status, and session
/// history using SQLite (sqflite) — fully on-device, no server, matching
/// the approved SRS ("no server required for core functionality").
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
      version: 1,
      onCreate: (db, version) async {
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
        // single row holding the running totals
        await db.insert('app_state', {'id': 1, 'total_points': 0, 'premium_unlocked': 0});
      },
    );
  }

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

  /// Adds points to the running total and returns the new total.
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

  Future<void> saveSession({
    required String exercise,
    required double resultValue, // rep count or held seconds
    double? avgScore,
    required int pointsEarned,
  }) async {
    final db = await database;
    await db.insert('sessions', {
      'exercise': exercise,
      'result_value': resultValue,
      'avg_score': avgScore,
      'points_earned': pointsEarned,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getSessionHistory() async {
    final db = await database;
    return db.query('sessions', orderBy: 'timestamp DESC');
  }
}