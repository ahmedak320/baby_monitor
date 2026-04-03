import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/datasources/local/preferences_cache.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/parental_control_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/biometric_helper.dart';
import '../../parent_dashboard/providers/dashboard_provider.dart';
import '../widgets/pin_reset_dialog.dart';

class ChildSelectScreen extends ConsumerWidget {
  const ChildSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final fallbackChildren =
        dashboardStatsAsync.valueOrNull?.map((stats) => stats.child).toList() ??
        const <ChildProfile>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who\'s watching?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: childrenAsync.when(
        data: (children) => _buildChildrenGrid(context, ref, children),
        loading: () {
          if (fallbackChildren.isNotEmpty) {
            return _buildChildrenGrid(context, ref, fallbackChildren);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (e, _) {
          if (fallbackChildren.isNotEmpty) {
            return _buildChildrenGrid(context, ref, fallbackChildren);
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong. Please try again.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(childrenProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildrenGrid(
    BuildContext context,
    WidgetRef ref,
    List<ChildProfile> children,
  ) {
    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.child_care, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No children added yet.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.pushNamed(RouteNames.addChild),
              icon: const Icon(Icons.add),
              label: const Text('Add a child'),
            ),
          ],
        ),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    final authenticated = await _authenticateParent(
                      context,
                      child.name,
                    );
                    if (authenticated && context.mounted) {
                      ref.read(currentChildProvider.notifier).setChild(child);
                      await ParentalControlService.enterKidMode();
                      if (context.mounted) {
                        context.goNamed(RouteNames.kidHome);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Authenticate the parent via biometrics first, then PIN fallback.
Future<bool> _authenticateParent(BuildContext context, String childName) async {
  final bioAvailable = await BiometricHelper.isAvailable;

  if (bioAvailable) {
    final success = await BiometricHelper.authenticate(
      reason: 'Verify to start kid mode for $childName',
    );
    if (success) return true;
  }

  // Biometric failed or unavailable — check if PIN is set
  if (!context.mounted) return false;

  final hasPin = await ParentalControlService.hasPinSet();
  if (!hasPin && context.mounted) {
    // No PIN set — prompt to create one
    final newPin = await showCreatePinDialog(context);
    if (newPin != null) {
      try {
        await ParentalControlService.setPin(newPin);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save the new PIN. Please try again.'),
            ),
          );
        }
        return false;
      }
      return true; // PIN was just created — grant access
    }
    return false;
  }

  // PIN exists — show verification dialog
  if (context.mounted) {
    final verified = await showPinVerificationDialog(context);
    if (verified) {
      await PreferencesCache.resetPinLockout();
    }
    return verified;
  }
  return false;
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Age $age · $bracket',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
