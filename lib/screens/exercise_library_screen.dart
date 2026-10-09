import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../data/exercise_catalog.dart';
import '../services/database_service.dart';
import '../services/points_service.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  ExerciseCategory? _selectedCategory;
  String _searchQuery = "";
  int _totalPoints = 0;
  bool _isPremiumUnlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
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

  List<Exercise> get _filteredExercises {
    return ExerciseCatalog.allExercises.where((e) {
      final matchesCategory = _selectedCategory == null || e.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.targetMuscles.any((m) => m.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    final filteredList = _filteredExercises;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text("Exercise Library", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Category Filter Section
          Container(
            color: const Color(0xFF161A21),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: "Search exercises or muscle groups...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0F1115),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text("All"),
                          selected: _selectedCategory == null,
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(
                            color: _selectedCategory == null ? Colors.white : Colors.white70,
                            fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFF0F1115),
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                      ),
                      ...ExerciseCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_categoryLabel(cat)),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: const Color(0xFF0F1115),
                            onSelected: (selected) {
                              setState(() => _selectedCategory = selected ? cat : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Exercise List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Reward Points Status Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A21),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isPremiumUnlocked
                              ? "$_totalPoints Points • Premium Module Unlocked!"
                              : "$_totalPoints Points • ${PointsService.unlockThreshold - _totalPoints} pts to unlock Premium exercises",
                          style: TextStyle(
                            color: _isPremiumUnlocked ? Colors.greenAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (filteredList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        "No exercises match your filter.",
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...filteredList.map((exercise) {
                    final isLocked = exercise.isPremium && !_isPremiumUnlocked;

                    return Card(
                      color: isLocked
                          ? const Color(0xFF161A21).withValues(alpha: 0.5)
                          : const Color(0xFF161A21),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isLocked ? Colors.white10 : Colors.teal.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: isLocked ? Colors.white12 : Colors.teal[800],
                          child: Icon(
                            isLocked
                                ? Icons.lock
                                : exercise.analysisType == AnalysisType.repetition
                                    ? Icons.fitness_center
                                    : Icons.timer,
                            color: isLocked ? Colors.white38 : Colors.tealAccent,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              exercise.name,
                              style: TextStyle(
                                color: isLocked ? Colors.white38 : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (exercise.isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "PRO",
                                  style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              exercise.targetMuscles.join(" • "),
                              style: TextStyle(
                                color: isLocked ? Colors.white24 : Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _SmallChip(
                                  label: exercise.categoryLabel,
                                  color: Colors.tealAccent,
                                ),
                                const SizedBox(width: 6),
                                _SmallChip(
                                  label: exercise.difficultyLabel,
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isLocked ? Colors.white24 : Colors.white38,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(exercise: exercise),
                            ),
                          );
                          _loadPoints();
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.upperBody:
        return "Upper Body";
      case ExerciseCategory.lowerBody:
        return "Lower Body";
      case ExerciseCategory.core:
        return "Core";
      case ExerciseCategory.fullBodyCardio:
        return "Full Body";
      case ExerciseCategory.mobilityYoga:
        return "Mobility & Yoga";
    }
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
