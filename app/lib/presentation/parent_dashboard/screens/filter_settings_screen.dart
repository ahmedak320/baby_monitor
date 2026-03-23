import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/age_recommendation_service.dart';
import '../../../providers/current_user_provider.dart';
import '../../../utils/age_calculator.dart';

class FilterSettingsScreen extends ConsumerStatefulWidget {
  const FilterSettingsScreen({super.key});

  @override
  ConsumerState<FilterSettingsScreen> createState() =>
      _FilterSettingsScreenState();
}

class _FilterSettingsScreenState extends ConsumerState<FilterSettingsScreen> {
  final _profileRepo = ProfileRepository();
  List<ChildProfile> _children = [];
  int _selectedChildIndex = 0;
  Map<String, double> _sensitivity = {};
  bool _isLoading = true;
  bool _isSaving = false;

  static const _sliderLabels = {
    'overstimulation': ('Overstimulation', 'How strictly to filter rapid/chaotic visuals'),
    'scariness': ('Scariness', 'How strictly to filter scary content'),
    'brainrot_tolerance': ('Brainrot', 'How strictly to filter mindless content'),
    'language_strictness': ('Language', 'How strictly to filter bad language'),
    'educational_preference': ('Educational', 'How much to prefer educational content'),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final children = await _profileRepo.getChildren();
    if (mounted && children.isNotEmpty) {
      setState(() {
        _children = children;
        _loadChildSensitivity(0);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _loadChildSensitivity(int index) {
    final child = _children[index];
    _sensitivity = Map.from(child.filterSensitivity.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ));
    // Ensure all keys exist
    for (final key in _sliderLabels.keys) {
      _sensitivity.putIfAbsent(key, () => 5.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Filter Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_children.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Filter Settings')),
        body: const Center(child: Text('No children added yet')),
      );
    }

    final child = _children[_selectedChildIndex];
    final age = AgeCalculator.yearsFromDob(child.dateOfBirth);
    final bracket = AgeRecommendationService.getConfigForAge(age);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Child selector
          if (_children.length > 1)
            SegmentedButton<int>(
              segments: _children.asMap().entries.map((e) {
                return ButtonSegment(
                  value: e.key,
                  label: Text(e.value.name),
                );
              }).toList(),
              selected: {_selectedChildIndex},
              onSelectionChanged: (s) {
                setState(() {
                  _selectedChildIndex = s.first;
                  _loadChildSensitivity(s.first);
                });
              },
            ),

          const SizedBox(height: 16),

          // Age recommendation banner
          Card(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Color(0xFF6C63FF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${child.name} is $age (${bracket.label})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Adjust sliders to customize filtering. Higher = stricter.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _resetToDefaults,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sensitivity sliders
          for (final entry in _sliderLabels.entries)
            _FilterSlider(
              label: entry.value.$1,
              description: entry.value.$2,
              value: _sensitivity[entry.key] ?? 5.0,
              onChanged: (v) {
                setState(() => _sensitivity[entry.key] = v);
              },
            ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    final child = _children[_selectedChildIndex];
    final age = AgeCalculator.yearsFromDob(child.dateOfBirth);
    final defaults = AgeRecommendationService.getDefaultSensitivity(age);
    setState(() => _sensitivity = defaults);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final child = _children[_selectedChildIndex];

    await _profileRepo.updateChild(child.id, {
      'filter_sensitivity': _sensitivity,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      ref.invalidate(childrenProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filter settings saved')),
      );
    }
  }
}

class _FilterSlider extends StatelessWidget {
  final String label;
  final String description;
  final double value;
  final ValueChanged<double> onChanged;

  const _FilterSlider({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorForValue(value).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.round().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _colorForValue(value),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lenient', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text('Strict', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForValue(double v) {
    if (v <= 3) return Colors.green;
    if (v <= 6) return Colors.orange;
    return Colors.red;
  }
}
