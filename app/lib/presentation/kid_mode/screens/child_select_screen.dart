import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/current_child_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/biometric_helper.dart';

class ChildSelectScreen extends ConsumerWidget {
  const ChildSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who\'s watching?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(RouteNames.dashboard),
        ),
      ),
      body: childrenAsync.when(
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Text('No children added yet.\nGo to settings to add a child.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text(
                  'Tap a profile to start watching',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final age = AgeCalculator.yearsFromDob(child.dateOfBirth);
                      final bracket = AgeCalculator.ageBracket(child.dateOfBirth);

                      return _ChildAvatar(
                        name: child.name,
                        age: age,
                        bracket: bracket,
                        colorIndex: index,
                        onTap: () async {
                          // Authenticate before starting kid mode
                          final auth = await BiometricHelper.authenticate(
                            reason: 'Verify to start kid mode for ${child.name}',
                          );
                          if (!auth && context.mounted) {
                            // Fallback: just proceed (biometrics optional)
                          }
                          if (context.mounted) {
                            ref
                                .read(currentChildProvider.notifier)
                                .setChild(child);
                            context.goNamed(RouteNames.kidHome);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final String name;
  final int age;
  final String bracket;
  final int colorIndex;
  final VoidCallback onTap;

  const _ChildAvatar({
    required this.name,
    required this.age,
    required this.bracket,
    required this.colorIndex,
    required this.onTap,
  });

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF6C63FF),
    Color(0xFFFF9FF3),
    Color(0xFF54A0FF),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[colorIndex % _colors.length];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Age $age · $bracket',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
