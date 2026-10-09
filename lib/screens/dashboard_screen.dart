import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/profile_service.dart';
import '../models/user_profile.dart';
import '../models/personal_record.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();
  bool _loading = true;

  int _totalSessions = 0;
  int _totalReps = 0;
  double _totalHoldSeconds = 0;
  int _totalPoints = 0;
  bool _isPremiumUnlocked = false;

  UserProfile _profile = const UserProfile();
  List<PersonalRecord> _personalRecords = [];
  List<int> _weeklyActivity = List.filled(7, 0);
  List<Map<String, Object?>> _recentSessions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final stats = await _db.getDashboardStats();
    final unlocked = await _db.isPremiumUnlocked();

    if (mounted) {
      setState(() {
        _totalSessions = stats['totalSessions'] as int;
        _totalReps = stats['totalReps'] as int;
        _totalHoldSeconds = stats['totalHoldSeconds'] as double;
        _totalPoints = stats['totalPoints'] as int;
        _isPremiumUnlocked = unlocked;
        _profile = stats['profile'] as UserProfile;
        _personalRecords = stats['personalRecords'] as List<PersonalRecord>;
        _weeklyActivity = stats['weeklyActivity'] as List<int>;
        _recentSessions = stats['recentSessions'] as List<Map<String, Object?>>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(

title: Row(
  children: [
    Image.asset(
      'assets/branding/posturex_logo.png',
      width: 38,
      height: 38,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.fitness_center,
          color: Colors.tealAccent,
          size: 28,
        );
      },
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        "Welcome back, ${_profile.nickname ?? _profile.name}!",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),

        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.tealAccent,
        backgroundColor: const Color(0xFF161A21),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Goal Adaptation Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade900.withValues(alpha: 0.8), const Color(0xFF161A21)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.track_changes, color: Colors.tealAccent, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Goal: ${ProfileService.goalLabel(_profile.fitnessGoal)}",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ProfileService.getGoalTip(_profile.fitnessGoal),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Stat Cards (2x2 Grid)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Sessions Completed",
                    value: "$_totalSessions",
                    icon: Icons.fitness_center,
                    color: Colors.tealAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: "Total Repetitions",
                    value: "$_totalReps",
                    icon: Icons.repeat,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Hold Time",
                    value: "${_totalHoldSeconds.round()}s",
                    icon: Icons.timer,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: "Points Earned",
                    value: "$_totalPoints",
                    subtitle: _isPremiumUnlocked ? "Premium Unlocked" : "Threshold 300",
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Activity Progress Visualization
            _sectionHeader("Weekly Workout Activity"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161A21),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Workouts completed in the last 7 days",
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _WeeklyBarChart(activity: _weeklyActivity),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Personal Records (PRs)
            _sectionHeader("Personal Records"),
            const SizedBox(height: 12),
            _personalRecords.isEmpty
                ? _emptyCard("No personal records set yet. Complete workout sessions to set records!")
                : Column(
                    children: _personalRecords.map((pr) {
                      final isHold = pr.exercise.toLowerCase().contains('plank') ||
                          pr.exercise.toLowerCase().contains('pose');
                      final formattedVal = isHold ? "${pr.maxResult.toStringAsFixed(1)}s hold" : "${pr.maxResult.round()} reps";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161A21),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.amber,
                              radius: 18,
                              child: Icon(Icons.emoji_events, color: Colors.black, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pr.exercise,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Best Score: ${pr.bestScore.toStringAsFixed(1)} / 10",
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formattedVal,
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${pr.updatedAt.day}/${pr.updatedAt.month}/${pr.updatedAt.year}",
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

            // Recent Activity Log
            _sectionHeader("Recent Activity"),
            const SizedBox(height: 12),
            _recentSessions.isEmpty
                ? _emptyCard("No workout sessions recorded yet.")
                : Column(
                    children: _recentSessions.map((s) {
                      final exercise = s['exercise'] as String;
                      final resultVal = (s['result_value'] as num).toDouble();
                      final score = s['avg_score'] != null ? (s['avg_score'] as num).toDouble() : null;
                      final pts = s['points_earned'] as int;
                      final dateStr = s['timestamp'] as String;
                      final date = DateTime.tryParse(dateStr);

                      final isHold = exercise.toLowerCase().contains('plank') || exercise.toLowerCase().contains('pose');
                      final displayResult = isHold ? "${resultVal.toStringAsFixed(1)} seconds" : "${resultVal.round()} reps";

                      return Card(
                        color: const Color(0xFF161A21),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.history, color: Colors.tealAccent),
                          title: Text(exercise, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "$displayResult ${score != null ? '• Form: ${score.toStringAsFixed(1)}/10' : ''}",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "+$pts pts",
                                style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (date != null)
                                Text(
                                  "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<int> activity;
  const _WeeklyBarChart({required this.activity});

  @override
  Widget build(BuildContext context) {
    const days = ["M", "T", "W", "T", "F", "S", "S"];
    final maxVal = activity.fold<int>(1, (max, v) => v > max ? v : max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final count = activity[index];
        final heightFactor = (count / maxVal).clamp(0.1, 1.0);

        return Column(
          children: [
            Text(
              count > 0 ? "$count" : "",
              style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: 70 * heightFactor,
              decoration: BoxDecoration(
                color: count > 0 ? Colors.teal : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              days[index],
              style: TextStyle(
                color: count > 0 ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
