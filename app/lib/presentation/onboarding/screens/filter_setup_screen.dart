import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';
import '../providers/onboarding_provider.dart';

class FilterSetupScreen extends ConsumerStatefulWidget {
  const FilterSetupScreen({super.key});

  @override
  ConsumerState<FilterSetupScreen> createState() => _FilterSetupScreenState();
}

class _FilterSetupScreenState extends ConsumerState<FilterSetupScreen> {
  late List<String> _priorities;

  static const _filterLabels = {
    'overstimulation': 'Overstimulating Content',
    'brainrot': 'Brainrot / Low-Quality',
    'scariness': 'Scary / Disturbing',
    'language': 'Bad Language',
    'ads': 'Ads & Commercial Content',
  };

  static const _filterIcons = {
    'overstimulation': Icons.flash_on,
    'brainrot': Icons.sentiment_dissatisfied,
    'scariness': Icons.warning_amber,
    'language': Icons.chat_bubble_outline,
    'ads': Icons.shopping_bag_outlined,
  };

  static const _filterDescriptions = {
    'overstimulation': 'Rapid editing, flashing colors, chaotic scenes',
    'brainrot': 'Repetitive, mindless content with no value',
    'scariness': 'Monsters, jump scares, dark themes',
    'language': 'Profanity, inappropriate talk',
    'ads': 'Product placement, toy unboxing spam',
  };

  @override
  void initState() {
    super.initState();
    _priorities = List.from(ref.read(onboardingProvider).filterPriorities);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Priorities'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What concerns you most?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drag to reorder by importance. #1 will be filtered most strictly.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _priorities.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _priorities.removeAt(oldIndex);
                    _priorities.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final key = _priorities[index];
                  return _PriorityTile(
                    key: ValueKey(key),
                    rank: index + 1,
                    label: _filterLabels[key] ?? key,
                    description: _filterDescriptions[key] ?? '',
                    icon: _filterIcons[key] ?? Icons.help_outline,
                    sensitivity: state.filterSensitivity[key] ?? 5,
                    onSensitivityChanged: (value) {
                      ref
                          .read(onboardingProvider.notifier)
                          .setFilterSensitivity(key, value);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(onboardingProvider.notifier)
                      .setFilterPriorities(_priorities);
                  context.pushNamed(RouteNames.channelSuggestions);
                },
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityTile extends StatelessWidget {
  final int rank;
  final String label;
  final String description;
  final IconData icon;
  final double sensitivity;
  final ValueChanged<double> onSensitivityChanged;

  const _PriorityTile({
    super.key,
    required this.rank,
    required this.label,
    required this.description,
    required this.icon,
    required this.sensitivity,
    required this.onSensitivityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _rankColor(rank),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.drag_handle, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Lenient', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: sensitivity,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: sensitivity.round().toString(),
                    onChanged: onSensitivityChanged,
                  ),
                ),
                const Text('Strict', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
