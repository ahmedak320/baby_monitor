import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../routing/route_names.dart';
import '../providers/onboarding_provider.dart';

class ContentPrefsScreen extends ConsumerWidget {
  const ContentPrefsScreen({super.key});

  static const _contentIcons = {
    'educational': Icons.school,
    'nature': Icons.nature,
    'cartoons': Icons.animation,
    'music': Icons.music_note,
    'storytime': Icons.auto_stories,
    'fun': Icons.celebration,
    'soothing': Icons.spa,
    'creative': Icons.palette,
  };

  static const _contentColors = {
    'educational': Color(0xFF2196F3),
    'nature': Color(0xFF4CAF50),
    'cartoons': Color(0xFFFF9800),
    'music': Color(0xFF9C27B0),
    'storytime': Color(0xFF795548),
    'fun': Color(0xFFE91E63),
    'soothing': Color(0xFF00BCD4),
    'creative': Color(0xFFFF5722),
  };

  static const _contentDescriptions = {
    'educational': 'Science, math, letters, and learning',
    'nature': 'Animals, wildlife, and the outdoors',
    'cartoons': 'Age-appropriate animated shows',
    'music': 'Nursery rhymes, songs, and dance',
    'storytime': 'Read-along stories and audiobooks',
    'fun': 'Games, challenges, and lighthearted content',
    'soothing': 'Calming music and gentle visuals',
    'creative': 'Art, crafts, and DIY activities',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Content Types')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What should ${state.childName} watch?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to cycle: preferred (green) > allowed (blue) > blocked (red). '
                    'Preferred content appears more often.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: AppConstants.contentTypes.length,
                itemBuilder: (context, index) {
                  final type = AppConstants.contentTypes[index];
                  final pref = state.contentPreferences[type] ?? 'allowed';

                  return _ContentTile(
                    type: type,
                    preference: pref,
                    icon: _contentIcons[type] ?? Icons.category,
                    color: _contentColors[type] ?? Colors.grey,
                    description: _contentDescriptions[type] ?? '',
                    onTap: () {
                      // Cycle: allowed -> preferred -> blocked -> allowed
                      final next = switch (pref) {
                        'allowed' => 'preferred',
                        'preferred' => 'blocked',
                        _ => 'allowed',
                      };
                      ref
                          .read(onboardingProvider.notifier)
                          .setContentPreference(type, next);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () => context.pushNamed(RouteNames.setupComplete),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  final String type;
  final String preference;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;

  const _ContentTile({
    required this.type,
    required this.preference,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (preference) {
      'preferred' => Colors.green,
      'blocked' => Colors.red,
      _ => Colors.grey[300]!,
    };
    final badgeText = switch (preference) {
      'preferred' => 'PREFERRED',
      'blocked' => 'BLOCKED',
      _ => 'ALLOWED',
    };
    final badgeColor = switch (preference) {
      'preferred' => Colors.green,
      'blocked' => Colors.red,
      _ => Colors.blue,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          color: borderColor.withValues(alpha: 0.05),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              type[0].toUpperCase() + type.substring(1),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
