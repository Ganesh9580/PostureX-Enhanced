import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;

  ExperienceLevel _selectedExperience = ExperienceLevel.beginner;
  FitnessGoal _selectedGoal = FitnessGoal.generalFitness;
  MeasurementUnit _selectedUnit = MeasurementUnit.metric;
  String _selectedDuration = "15-20 min";

  bool _loading = true;
  bool _isSaving = false;
  double _completionRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nicknameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _notesController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {
        _nameController.text = profile.name;
        _nicknameController.text = profile.nickname ?? "";
        _ageController.text = profile.age?.toString() ?? "";
        _heightController.text = profile.height?.toString() ?? "";
        _weightController.text = profile.weight?.toString() ?? "";
        _notesController.text = profile.notes ?? "";
        _selectedExperience = profile.experienceLevel;
        _selectedGoal = profile.fitnessGoal;
        _selectedUnit = profile.unit;
        _selectedDuration = profile.preferredDuration;
        _completionRatio = profile.completionPercentage;
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updated = UserProfile(
      name: _nameController.text.trim().isEmpty ? "Athlete" : _nameController.text.trim(),
      nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      height: double.tryParse(_heightController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      experienceLevel: _selectedExperience,
      fitnessGoal: _selectedGoal,
      preferredDuration: _selectedDuration,
      unit: _selectedUnit,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await _profileService.updateProfile(updated);

    if (mounted) {
      setState(() {
        _completionRatio = updated.completionPercentage;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully!"),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
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

    final unitLabelHeight = _selectedUnit == MeasurementUnit.metric ? "cm" : "in";
    final unitLabelWeight = _selectedUnit == MeasurementUnit.metric ? "kg" : "lbs";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161A21),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Completion & Avatar Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161A21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.teal[800],
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text[0].toUpperCase()
                              : "A",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text.isEmpty ? "Athlete" : _nameController.text,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (_nicknameController.text.isNotEmpty)
                              Text(
                                '"${_nicknameController.text}"',
                                style: const TextStyle(color: Colors.tealAccent, fontSize: 14),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _BadgeChip(label: ProfileService.experienceLabel(_selectedExperience), color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                _BadgeChip(label: ProfileService.goalLabel(_selectedGoal), color: Colors.amber),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Profile Completion",
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "${(_completionRatio * 100).round()}%",
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _completionRatio,
                      backgroundColor: Colors.white12,
                      color: Colors.tealAccent,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Personal Information
            _sectionHeader("Personal Information"),
            const SizedBox(height: 10),

            _buildTextField(
              controller: _nameController,
              label: "Full Name",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _nicknameController,
              label: "Nickname (Optional)",
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ageController,
                    label: "Age",
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _heightController,
                    label: "Height ($unitLabelHeight)",
                    icon: Icons.height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _weightController,
                    label: "Weight ($unitLabelWeight)",
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Measurement Units
            _sectionHeader("Preferred Units"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Metric (kg, cm)")),
                    selected: _selectedUnit == MeasurementUnit.metric,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(color: _selectedUnit == MeasurementUnit.metric ? Colors.white : Colors.white70),
                    backgroundColor: const Color(0xFF161A21),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedUnit = MeasurementUnit.metric);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Imperial (lbs, in)")),
                    selected: _selectedUnit == MeasurementUnit.imperial,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(color: _selectedUnit == MeasurementUnit.imperial ? Colors.white : Colors.white70),
                    backgroundColor: const Color(0xFF161A21),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedUnit = MeasurementUnit.imperial);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Fitness Experience & Goal
            _sectionHeader("Fitness Experience"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ExperienceLevel.values.map((level) {
                final isSelected = _selectedExperience == level;
                return ChoiceChip(
                  label: Text(ProfileService.experienceLabel(level)),
                  selected: isSelected,
                  selectedColor: Colors.teal[700],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  backgroundColor: const Color(0xFF161A21),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedExperience = level);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _sectionHeader("Primary Fitness Goal"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FitnessGoal.values.map((goal) {
                final isSelected = _selectedGoal == goal;
                return ChoiceChip(
                  label: Text(ProfileService.goalLabel(goal)),
                  selected: isSelected,
                  selectedColor: Colors.amber[800],
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  backgroundColor: const Color(0xFF161A21),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGoal = goal);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Goal Tip Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.tealAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ProfileService.getGoalTip(_selectedGoal),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section: Preferred Duration
            _sectionHeader("Preferred Workout Duration"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ["5-10 min", "15-20 min", "30+ min"].map((dur) {
                final isSelected = _selectedDuration == dur;
                return ChoiceChip(
                  label: Text(dur),
                  selected: isSelected,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                  backgroundColor: const Color(0xFF161A21),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDuration = dur);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Section: Notes
            _sectionHeader("Optional Fitness Notes"),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _notesController,
              label: "Injury history, target areas, or notes...",
              icon: Icons.note_alt_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? "Saving..." : "Save Profile",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Center(
              child: Text(
                "🔒 All profile data is stored on-device in local SQLite storage.",
                style: TextStyle(color: Colors.white38, fontSize: 12),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF161A21),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
