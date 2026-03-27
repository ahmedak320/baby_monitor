import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/services/parental_control_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/biometric_helper.dart';

// Brute-force protection state for PIN fallback dialog
int _pinAttempts = 0;
DateTime? _lockoutUntil;
int _lockoutDurationSeconds = 30;
const int _maxPinAttempts = 5;

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
          onPressed: () => context.pop(),
        ),
      ),
      body: childrenAsync.when(
        data: (children) {
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
                          final authenticated =
                              await _authenticateParent(context, child.name);
                          if (authenticated && context.mounted) {
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
        error: (e, _) => const Center(child: Text('Something went wrong. Please try again.')),
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

  // Biometric failed or unavailable — fall back to PIN dialog
  if (context.mounted) {
    return _showPinFallbackDialog(context);
  }
  return false;
}

void _resetPinCounters() {
  _pinAttempts = 0;
  _lockoutUntil = null;
  _lockoutDurationSeconds = 30;
}

/// Show a PIN entry dialog that validates against the stored hash.
/// Includes brute-force protection with exponential lockout.
Future<bool> _showPinFallbackDialog(BuildContext context) async {
  // Check lockout before showing dialog
  if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
    final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many failed attempts. Try again in $remaining seconds.',
          ),
        ),
      );
    }
    return false;
  }

  final controller = TextEditingController();
  final remainingAttempts = _maxPinAttempts - _pinAttempts;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter Parent PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(
              hintText: '4-digit PIN',
            ),
          ),
          if (remainingAttempts < _maxPinAttempts)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$remainingAttempts attempts remaining',
                style: TextStyle(
                  color: remainingAttempts <= 2 ? Colors.red : Colors.orange,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final pin = controller.text;
            if (pin.length != 4) return;
            final verified = await ParentalControlService.verifyPin(pin);
            if (ctx.mounted) {
              if (verified) {
                _resetPinCounters();
                Navigator.pop(ctx, true);
              } else {
                _pinAttempts++;
                if (_pinAttempts >= _maxPinAttempts) {
                  // Apply lockout with exponential backoff (max 1 hour)
                  _lockoutUntil = DateTime.now().add(
                    Duration(seconds: _lockoutDurationSeconds),
                  );
                  _lockoutDurationSeconds = min(
                    _lockoutDurationSeconds * 2,
                    3600,
                  );
                  _pinAttempts = 0; // Reset attempt count for next round
                  if (ctx.mounted) {
                    Navigator.pop(ctx, false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Too many failed attempts. Locked for '
                          '${_lockoutDurationSeconds ~/ 2} seconds.',
                        ),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Incorrect PIN. '
                        '${_maxPinAttempts - _pinAttempts} attempts remaining.',
                      ),
                    ),
                  );
                }
              }
            }
          },
          child: const Text('Verify'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result ?? false;
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
