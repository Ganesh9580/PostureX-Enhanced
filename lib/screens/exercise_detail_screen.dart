import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import 'tracking_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isPremiumUnlocked = false;
  int _userPoints = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final unlocked = await _db.isPremiumUnlocked();
    final points = await _db.getTotalPoints();
    if (mounted) {
      setState(() {
        _isPremiumUnlocked = unlocked;
        _userPoints = points;
        _loading = false;
      });
    }
  }

  void _startWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingScreen(exercise: widget.exercise.exerciseType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final isLocked = exercise.isPremium && !_isPremiumUnlocked;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card with Category, Difficulty, & Lock Status
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A21),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLocked
                          ? Colors.amber.withValues(alpha: 0.4)
                          : Colors.teal.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Badge(
                            label: exercise.categoryLabel,
                            color: Colors.tealAccent,
                          ),
                          _Badge(
                            label: exercise.difficultyLabel,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercise.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            exercise.analysisType == AnalysisType.repetition
                                ? Icons.repeat
                                : Icons.timer,
                            color: Colors.tealAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            exercise.analysisType == AnalysisType.repetition
                                ? "Default Goal: ${exercise.defaultGoal} reps"
                                : "Default Goal: ${exercise.defaultGoal} seconds hold",
                            style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Target Muscles Section
                _sectionHeader("Target Muscle Groups"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exercise.targetMuscles.map((muscle) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        muscle,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Camera Setup Instructions Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A21),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: Colors.cyanAccent, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Camera Positioning Guide",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exercise.cameraSetupGuide,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Step-by-Step Instructions
                _sectionHeader("How to Perform"),
                const SizedBox(height: 10),
                Column(
                  children: List.generate(exercise.instructions.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A21),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.teal[800],
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              exercise.instructions[index],
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30),

                // Action Launch Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isLocked ? null : _startWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLocked ? Colors.white12 : Colors.teal[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isLocked ? Icons.lock : Icons.play_arrow),
                    label: Text(
                      isLocked
                          ? "Locked (Requires 300 Points — Current: $_userPoints)"
                          : "Start Exercise with AI Coach",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
