import 'package:flutter/material.dart';
import '../models/workout_routine.dart';
import '../models/user_profile.dart';
import '../services/routine_service.dart';
import '../services/database_service.dart';
import 'routine_editor_screen.dart';
import 'routine_player_screen.dart';

class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  final RoutineService _routineService = RoutineService();
  final DatabaseService _db = DatabaseService();

  List<WorkoutRoutine> _routines = [];
  UserProfile _profile = const UserProfile();
  bool _loading = true;
  bool _filterCustomOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final routines = await _routineService.loadAllRoutines();
    final profile = await _db.getUserProfile();
    if (mounted) {
      setState(() {
        _routines = routines;
        _profile = profile;
        _loading = false;
      });
    }
  }

  List<WorkoutRoutine> get _filteredRoutines {
    if (_filterCustomOnly) {
      return _routines.where((r) => r.isCustom).toList();
    }
    return _routines;
  }

  void _openEditor([WorkoutRoutine? routine]) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(existingRoutine: routine)),
    );
    if (updated == true) {
      _loadData();
    }
  }

  void _deleteCustom(String id) async {
    await _routineService.deleteCustomRoutine(id);
    _loadData();
  }

  void _startRoutine(WorkoutRoutine routine) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutinePlayerScreen(routine: routine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    final displayed = _filteredRoutines;
    final recommended = RoutineService.getRecommendedRoutines(_routines, _profile);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text("Workout Routines", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal[600],
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text("Create Routine"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filter Tabs
          Row(
            children: [
              FilterChip(
                label: const Text("All Routines"),
                selected: !_filterCustomOnly,
                selectedColor: Colors.teal,
                labelStyle: TextStyle(color: !_filterCustomOnly ? Colors.white : Colors.white70),
                backgroundColor: const Color(0xFF161A21),
                onSelected: (_) => setState(() => _filterCustomOnly = false),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("Custom Routines"),
                selected: _filterCustomOnly,
                selectedColor: Colors.teal,
                labelStyle: TextStyle(color: _filterCustomOnly ? Colors.white : Colors.white70),
                backgroundColor: const Color(0xFF161A21),
                onSelected: (_) => setState(() => _filterCustomOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (displayed.isEmpty)
            _emptyCard(_filterCustomOnly ? "No custom routines created yet. Tap 'Create Routine' below to build one!" : "No routines found.")
          else
            ...displayed.map((routine) {
              final isRec = recommended.any((r) => r.id == routine.id);
              final totalSets = routine.items.fold<int>(0, (sum, item) => sum + item.sets);

              return Card(
                color: const Color(0xFF161A21),
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isRec ? Colors.tealAccent.withValues(alpha: 0.4) : Colors.white10,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _Badge(label: routine.difficulty.name.toUpperCase(), color: Colors.amber),
                              if (isRec) ...[
                                const SizedBox(width: 8),
                                const _Badge(label: "RECOMMENDED", color: Colors.tealAccent),
                              ],
                            ],
                          ),
                          if (routine.isCustom)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white60),
                              color: const Color(0xFF161A21),
                              onSelected: (val) {
                                if (val == 'edit') _openEditor(routine);
                                if (val == 'delete') _deleteCustom(routine.id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text("Edit Routine", style: TextStyle(color: Colors.white))),
                                PopupMenuItem(value: 'delete', child: Text("Delete Routine", style: TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        routine.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        routine.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.fitness_center_outlined, color: Colors.tealAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${routine.items.length} exercises ($totalSets sets)",
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.timer_outlined, color: Colors.cyanAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "~${routine.estimatedMinutes} min",
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _startRoutine(routine),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text("Start Workout Routine", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161A21),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
