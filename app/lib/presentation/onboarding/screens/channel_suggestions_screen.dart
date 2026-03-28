import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../utils/age_calculator.dart';
import '../providers/onboarding_provider.dart';

/// Curated popular kids channels with metadata.
class _Channel {
  final String id;
  final String name;
  final String category;
  final int minAge;
  final int maxAge;
  final IconData icon;
  final Color color;

  const _Channel({
    required this.id,
    required this.name,
    required this.category,
    required this.minAge,
    required this.maxAge,
    required this.icon,
    required this.color,
  });
}

const _suggestedChannels = [
  // Toddlers (1-3)
  _Channel(
    id: 'UCbCmjCuTUZos6Inko4u57UQ',
    name: 'Cocomelon',
    category: 'Music & Nursery Rhymes',
    minAge: 1,
    maxAge: 4,
    icon: Icons.music_note,
    color: Color(0xFF4CAF50),
  ),
  _Channel(
    id: 'UC-Gkp36O-TIBdQRPgDzNYkQ',
    name: 'Hey Bear Sensory',
    category: 'Sensory / Calming',
    minAge: 0,
    maxAge: 3,
    icon: Icons.spa,
    color: Color(0xFF9C27B0),
  ),
  _Channel(
    id: 'UCkZFKuBPJLE8sCnFwFVq2Hg',
    name: 'Dave and Ava',
    category: 'Music & Learning',
    minAge: 1,
    maxAge: 4,
    icon: Icons.music_note,
    color: Color(0xFFFF9800),
  ),

  // Preschool (3-6)
  _Channel(
    id: 'UCWI-ohtRu8eoyisLmPsTCrQ',
    name: 'Sesame Street',
    category: 'Educational',
    minAge: 2,
    maxAge: 6,
    icon: Icons.school,
    color: Color(0xFF2196F3),
  ),
  _Channel(
    id: 'UC_x5XG1OV2P6uZZ5FSM9Ttw',
    name: 'Blippi',
    category: 'Educational Fun',
    minAge: 2,
    maxAge: 7,
    icon: Icons.explore,
    color: Color(0xFFFF5722),
  ),
  _Channel(
    id: 'UCLsooMJoIpl_7ux2jvdPB-Q',
    name: 'Peppa Pig',
    category: 'Cartoons',
    minAge: 2,
    maxAge: 6,
    icon: Icons.pets,
    color: Color(0xFFE91E63),
  ),
  _Channel(
    id: 'UC4KObfhPm_HMGP2WFHF6HmQ',
    name: 'Numberblocks',
    category: 'Math Education',
    minAge: 3,
    maxAge: 7,
    icon: Icons.calculate,
    color: Color(0xFF3F51B5),
  ),

  // Early School (5-8)
  _Channel(
    id: 'UC0v-tlzsn0QZwJnkiaUSJCKg',
    name: 'National Geographic Kids',
    category: 'Nature & Science',
    minAge: 5,
    maxAge: 12,
    icon: Icons.nature,
    color: Color(0xFF795548),
  ),
  _Channel(
    id: 'UCvO6uJUVJQ6SrATfsufsprA',
    name: 'SciShow Kids',
    category: 'Science',
    minAge: 5,
    maxAge: 10,
    icon: Icons.science,
    color: Color(0xFF009688),
  ),
  _Channel(
    id: 'UCVcQH8A634mauPrGbWs7jlg',
    name: 'Art for Kids Hub',
    category: 'Creative / Art',
    minAge: 4,
    maxAge: 10,
    icon: Icons.palette,
    color: Color(0xFFFF4081),
  ),

  // Older Kids (8-12)
  _Channel(
    id: 'UC7DdEm33SyaTDtWYGO2CwdA',
    name: 'Mark Rober',
    category: 'Science & Engineering',
    minAge: 8,
    maxAge: 14,
    icon: Icons.engineering,
    color: Color(0xFF607D8B),
  ),
  _Channel(
    id: 'UCHnyfMqiRRG1u-2MsSQLbXA',
    name: 'Veritasium',
    category: 'Science',
    minAge: 10,
    maxAge: 14,
    icon: Icons.lightbulb,
    color: Color(0xFFFFC107),
  ),
];

class ChannelSuggestionsScreen extends ConsumerWidget {
  const ChannelSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final childAge = state.childDob != null
        ? AgeCalculator.yearsFromDob(state.childDob!)
        : 3;

    // Sort channels: age-appropriate ones first
    final sorted = List<_Channel>.from(_suggestedChannels)
      ..sort((a, b) {
        final aRelevant = childAge >= a.minAge && childAge <= a.maxAge;
        final bRelevant = childAge >= b.minAge && childAge <= b.maxAge;
        if (aRelevant && !bRelevant) return -1;
        if (!aRelevant && bRelevant) return 1;
        return 0;
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Pick Channels')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channels ${state.childName} might enjoy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select channels to approve. You can always change this later.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.approvedChannelIds.length} selected',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final channel = sorted[index];
                  final isSelected = state.approvedChannelIds.contains(
                    channel.id,
                  );
                  final isAgeAppropriate =
                      childAge >= channel.minAge && childAge <= channel.maxAge;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected
                        ? channel.color.withValues(alpha: 0.1)
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: channel.color,
                        child: Icon(
                          channel.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        channel.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${channel.category} · Ages ${channel.minAge}-${channel.maxAge}',
                        style: TextStyle(
                          color: isAgeAppropriate
                              ? Colors.grey[600]
                              : Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: channel.color)
                          : const Icon(
                              Icons.circle_outlined,
                              color: Colors.grey,
                            ),
                      onTap: () {
                        ref
                            .read(onboardingProvider.notifier)
                            .toggleChannel(channel.id);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => context.pushNamed('contentPrefs'),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
