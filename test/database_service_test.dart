import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_posture_coach/services/database_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('posturex_test_');
    DatabaseService.testDatabasePath = p.join(tempDir.path, 'test.db');
    service = DatabaseService();
  });

  tearDown(() async {
    await DatabaseService.resetForTesting();
    DatabaseService.testDatabasePath = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('initializes database with zero points', () async {
    expect(await service.getTotalPoints(), 0);
  });

  test('adds points and preserves the total', () async {
    expect(await service.addPoints(20), 20);
    expect(await service.addPoints(15), 35);
    expect(await service.getTotalPoints(), 35);
  });

  test('saves and retrieves workout sessions', () async {
    await service.saveSession(
      exercise: 'Squats',
      resultValue: 10,
      avgScore: 8.5,
      pointsEarned: 20,
    );

    final history = await service.getSessionHistory();

    expect(history, hasLength(1));
    expect(history.first['exercise'], 'Squats');
    expect(history.first['result_value'], 10);
    expect(history.first['points_earned'], 20);
  });

  test('updates personal records when a better result is achieved', () async {
    await service.saveSession(
      exercise: 'Squats',
      resultValue: 10,
      avgScore: 7,
      pointsEarned: 20,
    );

    await service.saveSession(
      exercise: 'Squats',
      resultValue: 15,
      avgScore: 9,
      pointsEarned: 30,
    );

    final records = await service.getPersonalRecords();

    expect(records, hasLength(1));
    expect(records.first.maxResult, 15);
    expect(records.first.bestScore, 9);
  });

  test('calculates dashboard statistics from saved sessions', () async {
    await service.saveSession(
      exercise: 'Squats',
      resultValue: 10,
      avgScore: 8,
      pointsEarned: 20,
    );

    await service.saveSession(
      exercise: 'Plank',
      resultValue: 30,
      avgScore: 9,
      pointsEarned: 25,
    );

    final stats = await service.getDashboardStats();

    expect(stats['totalSessions'], 2);
    expect(stats['totalReps'], 10);
    expect(stats['totalHoldSeconds'], 30.0);
    expect(stats['recentSessions'], hasLength(2));
  });
}
