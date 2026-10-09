import 'package:flutter/material.dart';
import '../models/workout_routine.dart';
import '../models/user_profile.dart';
import '../data/exercise_catalog.dart';
import '../services/routine_service.dart';

class RoutineEditorScreen extends StatefulWidget {
  final WorkoutRoutine? existingRoutine;
  const RoutineEditorScreen({super.key, this.existingRoutine});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  final RoutineService _routineService = RoutineService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  ExperienceLevel _selectedDifficulty = ExperienceLevel.beginner;
  FitnessGoal _selectedGoal = FitnessGoal.generalFitness;
  List<WorkoutRoutineItem> _items = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRoutine;
    _nameController = TextEditingController(text: r?.name ?? "");
    _descriptionController = TextEditingController(text: r?.description ?? "");
    _durationController = TextEditingController(text: r?.estimatedMinutes.toString() ?? "15");

    if (r != null) {
      _selectedDifficulty = r.difficulty;
      _selectedGoal = r.fitnessGoal;
      _items = List.from(r.items);
    } else {
      // Default initial item
      _items.add(const WorkoutRoutineItem(
        exerciseId: 'squat',
        exerciseName: 'Squats',
        targetReps: 10,
        sets: 3,
        restSeconds: 30,
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _addExerciseItem() {
    final available = ExerciseCatalog.allExercises;
    final first = available.first;

    setState(() {
      _items.add(WorkoutRoutineItem(
        exerciseId: first.id,
        exerciseName: first.name,
        targetReps: first.defaultGoal,
        targetHoldSeconds: first.defaultGoal.toDouble(),
        sets: 3,
        restSeconds: 30,
      ));
    });
  }

  void _removeExerciseItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A routine must contain at least 1 exercise.")),
      );
      return;
    }
    setState(() => _items.removeAt(index));
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final routine = WorkoutRoutine(
      id: widget.existingRoutine?.id ?? "custom_${DateTime.now().millisecondsSinceEpoch}",
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? "Custom workout routine" : _descriptionController.text.trim(),
      difficulty: _selectedDifficulty,
      fitnessGoal: _selectedGoal,
      estimatedMinutes: int.tryParse(_durationController.text.trim()) ?? 15,
      isCustom: true,
      items: _items,
      createdAt: widget.existingRoutine?.createdAt ?? DateTime.now(),
    );

    await _routineService.saveCustomRoutine(routine);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(
          widget.existingRoutine == null ? "Create Custom Routine" : "Edit Routine",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Routine Name & Description
            _buildTextField(_nameController, "Routine Name", Icons.fitness_center),
            const SizedBox(height: 12),
            _buildTextField(_descriptionController, "Description (Optional)", Icons.notes),
            const SizedBox(height: 12),
            _buildTextField(
              _durationController,
              "Estimated Duration (Minutes)",
              Icons.timer_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Difficulty Chips
            _sectionHeader("Target Difficulty"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ExperienceLevel.values.map((lvl) {
                final isSelected = _selectedDifficulty == lvl;
                return ChoiceChip(
                  label: Text(lvl.name[0].toUpperCase() + lvl.name.substring(1)),
                  selected: isSelected,
                  selectedColor: Colors.teal[700],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  backgroundColor: const Color(0xFF161A21),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDifficulty = lvl);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Exercise Sequence Items List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader("Exercise Sequence"),
                TextButton.icon(
                  onPressed: _addExerciseItem,
                  icon: const Icon(Icons.add, color: Colors.tealAccent, size: 18),
                  label: const Text("Add Exercise", style: TextStyle(color: Colors.tealAccent)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A21),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.teal[800],
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: item.exerciseId,
                            dropdownColor: const Color(0xFF161A21),
                            isExpanded: true,
                            underline: const SizedBox(),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            items: ExerciseCatalog.allExercises.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.id,
                                child: Text(e.name),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId == null) return;
                              final newEx = ExerciseCatalog.getById(newId);
                              if (newEx == null) return;
                              setState(() {
                                _items[index] = WorkoutRoutineItem(
                                  exerciseId: newEx.id,
                                  exerciseName: newEx.name,
                                  targetReps: newEx.defaultGoal,
                                  targetHoldSeconds: newEx.defaultGoal.toDouble(),
                                  sets: item.sets,
                                  restSeconds: item.restSeconds,
                                );
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeExerciseItem(index),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CounterInput(
                            label: "Sets",
                            value: item.sets,
                            onChanged: (v) {
                              setState(() {
                                _items[index] = WorkoutRoutineItem(
                                  exerciseId: item.exerciseId,
                                  exerciseName: item.exerciseName,
                                  targetReps: item.targetReps,
                                  targetHoldSeconds: item.targetHoldSeconds,
                                  sets: v.clamp(1, 10),
                                  restSeconds: item.restSeconds,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CounterInput(
                            label: "Target",
                            value: item.targetHoldSeconds > 0 ? item.targetHoldSeconds.round() : item.targetReps,
                            onChanged: (v) {
                              setState(() {
                                _items[index] = WorkoutRoutineItem(
                                  exerciseId: item.exerciseId,
                                  exerciseName: item.exerciseName,
                                  targetReps: v.clamp(1, 100),
                                  targetHoldSeconds: v.clamp(1, 100).toDouble(),
                                  sets: item.sets,
                                  restSeconds: item.restSeconds,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CounterInput(
                            label: "Rest (s)",
                            value: item.restSeconds,
                            onChanged: (v) {
                              setState(() {
                                _items[index] = WorkoutRoutineItem(
                                  exerciseId: item.exerciseId,
                                  exerciseName: item.exerciseName,
                                  targetReps: item.targetReps,
                                  targetHoldSeconds: item.targetHoldSeconds,
                                  sets: item.sets,
                                  restSeconds: v.clamp(5, 180),
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Save Routine Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  _isSaving ? "Saving..." : "Save Routine",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: (v) => v == null || v.trim().isEmpty ? "Field cannot be empty" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF161A21),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _CounterInput extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _CounterInput({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => onChanged(value - 1),
              child: const Icon(Icons.remove_circle_outline, color: Colors.tealAccent, size: 20),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text("$value", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            InkWell(
              onTap: () => onChanged(value + 1),
              child: const Icon(Icons.add_circle_outline, color: Colors.tealAccent, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
