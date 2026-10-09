import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_routine.dart';
import '../data/exercise_catalog.dart';
import '../services/database_service.dart';
import '../services/points_service.dart';
import 'tracking_screen.dart';
import 'session_summary_screen.dart';

class RoutinePlayerScreen extends StatefulWidget {
  final WorkoutRoutine routine;
  const RoutinePlayerScreen({super.key, required this.routine});

  @override
  State<RoutinePlayerScreen> createState() => _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends State<RoutinePlayerScreen> {
  final DatabaseService _db = DatabaseService();

  int _itemIndex = 0;
  int _currentSet = 1;

  bool _isResting = false;
  int _restSecondsLeft = 30;
  Timer? _restTimer;

  int _totalRoutinePoints = 0;
  int _completedSetsTotal = 0;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startTrackingSet() async {
    final currentItem = widget.routine.items[_itemIndex];
    final exerciseObj = ExerciseCatalog.getById(currentItem.exerciseId);
    final exerciseType = exerciseObj?.exerciseType;

    if (exerciseType == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackingScreen(exercise: exerciseType)),
    );

    // Award points for completing the set
    final pts = PointsService.pointsForRep(9.0) * 5;
    _totalRoutinePoints += pts;
    _completedSetsTotal++;

    _onSetCompleted();
  }

  void _onSetCompleted() {
    final currentItem = widget.routine.items[_itemIndex];

    if (_currentSet < currentItem.sets) {
      _startRest(currentItem.restSeconds, isNextSetSameExercise: true);
    } else if (_itemIndex < widget.routine.items.length - 1) {
      _startRest(currentItem.restSeconds, isNextSetSameExercise: false);
    } else {
      _finishRoutine();
    }
  }

  void _startRest(int seconds, {required bool isNextSetSameExercise}) {
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsLeft = seconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restSecondsLeft > 1) {
        setState(() => _restSecondsLeft--);
      } else {
        _stopRest(isNextSetSameExercise: isNextSetSameExercise);
      }
    });
  }

  void _stopRest({required bool isNextSetSameExercise}) {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      if (isNextSetSameExercise) {
        _currentSet++;
      } else {
        _itemIndex++;
        _currentSet = 1;
      }
    });
  }

  void _finishRoutine() async {
    final bonus = PointsService.sessionBonus(false) * 2;
    await _db.addPoints(_totalRoutinePoints + bonus);
    await _db.saveSession(
      exercise: widget.routine.name,
      resultValue: _completedSetsTotal.toDouble(),
      avgScore: 9.2,
      pointsEarned: _totalRoutinePoints + bonus,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(
            title: widget.routine.name,
            resultValue: _completedSetsTotal.toDouble(),
            isHoldBased: false,
            avgScore: 9.2,
            pointsEarned: _totalRoutinePoints + bonus,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.routine.items[_itemIndex];
    final totalItems = widget.routine.items.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(widget.routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: _isResting ? _buildRestView() : _buildSetView(currentItem, totalItems),
    );
  }

  Widget _buildSetView(WorkoutRoutineItem item, int totalItems) {
    final isHold = item.targetHoldSeconds > 0;
    final targetStr = isHold ? "${item.targetHoldSeconds.round()} sec hold" : "${item.targetReps} reps";

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Routine Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Exercise ${_itemIndex + 1} of $totalItems",
              style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              "Set $_currentSet of ${item.sets}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ((_itemIndex + (_currentSet / item.sets)) / totalItems).clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            color: Colors.tealAccent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 30),

        // Exercise Target Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161A21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(
                isHold ? Icons.timer : Icons.fitness_center,
                color: Colors.tealAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                item.exerciseName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Target: $targetStr",
                style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Set $_currentSet / ${item.sets}",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Start Set Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _startTrackingSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text(
              "Start Set with AI Coach",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestView() {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          const Icon(Icons.hot_tub_outlined, color: Colors.cyanAccent, size: 56),
          const SizedBox(height: 16),
          const Text(
            "Rest Interval",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Catch your breath and stay hydrated!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 30),

          // Big Countdown Timer
          CircleAvatar(
            radius: 65,
            backgroundColor: const Color(0xFF161A21),
            child: Text(
              "$_restSecondsLeft",
              style: const TextStyle(color: Colors.tealAccent, fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() => _restSecondsLeft += 15);
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text("+15s"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  final isNextSame = _currentSet < widget.routine.items[_itemIndex].sets;
                  _stopRest(isNextSetSameExercise: isNextSame);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600], foregroundColor: Colors.white),
                child: const Text("Skip Rest"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
