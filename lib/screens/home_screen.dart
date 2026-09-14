import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/points_service.dart';
import '../services/calibration_manager.dart'; // for ExerciseType
import 'tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  int _totalPoints = 0;
  bool _isPremiumUnlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await _db.getTotalPoints();
    final unlocked = await _db.isPremiumUnlocked();
    if (mounted) {
      setState(() {
        _totalPoints = points;
        _isPremiumUnlocked = unlocked;
        _loading = false;
      });
    }
  }

  void _openExercise(ExerciseType exercise) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackingScreen(exercise: exercise)),
    );
    // Refresh points/unlock status when coming back from a session
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text("AI Posture Coach"),
        backgroundColor: Colors.teal[800],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Points summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A21),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$_totalPoints points",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isPremiumUnlocked
                                  ? "Premium unlocked!"
                                  : "${PointsService.unlockThreshold - _totalPoints} points to unlock Premium",
                              style: TextStyle(
                                color: _isPremiumUnlocked ? Colors.greenAccent : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            if (!_isPremiumUnlocked) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (_totalPoints / PointsService.unlockThreshold).clamp(0, 1),
                                  backgroundColor: Colors.white12,
                                  color: Colors.amber,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text("Free Module", style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _ExerciseCard(
                  title: "Squats",
                  subtitle: "Goal: 10 reps",
                  icon: Icons.fitness_center,
                  locked: false,
                  onTap: () => _openExercise(ExerciseType.squat),
                ),
                _ExerciseCard(
                  title: "Push-ups",
                  subtitle: "Goal: 5 reps",
                  icon: Icons.fitness_center,
                  locked: false,
                  onTap: () => _openExercise(ExerciseType.pushup),
                ),
                _ExerciseCard(
                  title: "Plank",
                  subtitle: "Goal: 20 seconds",
                  icon: Icons.timer,
                  locked: false,
                  onTap: () => _openExercise(ExerciseType.plank),
                ),

                const SizedBox(height: 24),
                const Text("Premium Module", style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _ExerciseCard(
                  title: "Jumping Jacks",
                  subtitle: _isPremiumUnlocked ? "Goal: 10 reps" : "Locked",
                  icon: Icons.accessibility_new,
                  locked: !_isPremiumUnlocked,
                  onTap: _isPremiumUnlocked ? () {} : null, // wired up once built
                ),
                _ExerciseCard(
                  title: "Jump Squats",
                  subtitle: _isPremiumUnlocked ? "Goal: 10 reps" : "Locked",
                  icon: Icons.accessibility_new,
                  locked: !_isPremiumUnlocked,
                  onTap: _isPremiumUnlocked ? () {} : null,
                ),
              ],
            ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool locked;
  final VoidCallback? onTap;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: locked ? const Color(0xFF161A21).withOpacity(0.5) : const Color(0xFF161A21),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(locked ? Icons.lock : icon, color: locked ? Colors.white38 : Colors.tealAccent),
        title: Text(title, style: TextStyle(color: locked ? Colors.white38 : Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: locked ? Colors.white24 : Colors.white70)),
        trailing: locked ? null : const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}