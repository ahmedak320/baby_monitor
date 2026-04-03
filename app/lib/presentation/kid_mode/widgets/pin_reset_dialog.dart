import 'package:flutter/material.dart';

import '../../../data/datasources/local/preferences_cache.dart';
import '../../../domain/services/parental_control_service.dart';

/// Unfocus any active text field, then pop the dialog.
///
/// Clearing focus before popping prevents the "dependents.isEmpty" assertion
/// that occurs when a focused TextField's InheritedWidget dependencies
/// (FocusMarker, FocusInheritedScope) race with the dialog route's
/// deactivation.
void _popDialog<T extends Object?>(BuildContext ctx, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.pop(ctx, result);
}

/// Push a dialog route and wait until its exit transition fully completes.
///
/// `showDialog` completes when the route is popped, which is earlier than the
/// route's final disposal. Chained dialogs with focused `TextField`s can then
/// trip `_dependents.isEmpty` while the previous route is still unwinding.
Future<T?> showSettledDialog<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );

  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}

/// Shows a "Forgot PIN?" flow:
/// 1. Solve a math problem to prove you're an adult
/// 2. Enter a new 4-digit PIN
/// 3. Confirm the new PIN
/// Returns true if the PIN was successfully reset.
Future<bool> showPinResetFlow(BuildContext context) async {
  return showPinResetFlowWithSaver(
    context,
    persistPin: ParentalControlService.setPin,
    verifyPin: ParentalControlService.verifyPin,
  );
}

Future<bool> showPinResetFlowWithSaver(
  BuildContext context, {
  required Future<void> Function(String pin) persistPin,
  required Future<bool> Function(String pin) verifyPin,
}) async {
  // Phase 1: Math problem
  final mathPassed = await _showMathChallenge(context);
  if (!mathPassed || !context.mounted) return false;

  // Phase 2 + 3: Create and confirm new PIN
  final newPin = await _showCreatePinFlow(context);
  if (newPin == null || !context.mounted) return false;

  // Save the new PIN
  try {
    await persistPin(newPin);
    final verified = await verifyPin(newPin);
    if (!verified && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('The new PIN could not be verified. Please try again.'),
        ),
      );
    }
    return verified;
  } catch (e, st) {
    debugPrint('showPinResetFlow failed to persist PIN: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Failed to save the new PIN. Please try again.'),
        ),
      );
    }
    return false;
  }
}

/// Shows a dialog to create + confirm a new PIN (no math gate).
/// Used by "Forgot PIN?" (after math gate) and by first-time PIN setup.
/// Returns the new PIN string, or null if cancelled.
Future<String?> showCreatePinDialog(BuildContext context) {
  return _showCreatePinFlow(context);
}

/// Shows a PIN verification dialog with lockout protection.
///
/// Returns true if the PIN was verified successfully (or reset via "Forgot
/// PIN?"). The caller is responsible for resetting the lockout counter on
/// success (via [PreferencesCache.resetPinLockout]).
Future<bool> showPinVerificationDialog(BuildContext context) async {
  if (PreferencesCache.isPinLockedOut) {
    final remaining = PreferencesCache.pinLockoutRemainingSeconds;
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
  String? errorText;
  bool isVerifying = false;

  final result = await showSettledDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final remainingAttempts =
            PreferencesCache.maxPinAttempts - PreferencesCache.pinAttempts;
        return AlertDialog(
          title: const Text('Enter Parent PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                enabled: !isVerifying,
                decoration: const InputDecoration(hintText: '4-digit PIN'),
              ),
              if (remainingAttempts < PreferencesCache.maxPinAttempts)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$remainingAttempts attempts remaining',
                    style: TextStyle(
                      color: remainingAttempts <= 2
                          ? Colors.red
                          : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx, false);
                    },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx, 'forgot');
                    },
              child: const Text('Forgot PIN?'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final pin = controller.text;
                      if (pin.length != 4) {
                        setDialogState(
                          () => errorText = 'PIN must be 4 digits',
                        );
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        errorText = null;
                      });

                      bool verified;
                      try {
                        verified = await ParentalControlService.verifyPin(pin);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          isVerifying = false;
                          errorText = 'Verification failed. Please try again.';
                        });
                        return;
                      }

                      if (!ctx.mounted) return;

                      if (verified) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(ctx, true);
                      } else {
                        final locked =
                            await PreferencesCache.incrementPinAttempts();
                        if (locked) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx, false);
                        } else {
                          controller.clear();
                          final left =
                              PreferencesCache.maxPinAttempts -
                              PreferencesCache.pinAttempts;
                          setDialogState(() {
                            isVerifying = false;
                            errorText =
                                'Incorrect PIN. $left attempts remaining.';
                          });
                        }
                      }
                    },
              child: isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();

  if (result == 'forgot' && context.mounted) {
    return showPinResetFlow(context);
  }
  return result == true;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Phase 1: Math problem challenge.
Future<bool> _showMathChallenge(BuildContext context) async {
  final problem = ParentalControlService.generateMathProblem();
  final controller = TextEditingController();
  int attempts = 0;
  String? errorText;

  final result = await showSettledDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Verify You\'re a Parent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Solve this to continue:',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  '${problem.question} = ?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                  decoration: InputDecoration(
                    hintText: 'Answer',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (attempts > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${3 - attempts} attempts remaining',
                      style: TextStyle(
                        color: attempts >= 2 ? Colors.red : Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _popDialog(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final answer = int.tryParse(controller.text.trim());
                if (answer == problem.answer) {
                  _popDialog(ctx, true);
                } else {
                  attempts++;
                  if (attempts >= 3) {
                    _popDialog(ctx, false);
                  } else {
                    controller.clear();
                    setDialogState(
                      () => errorText = 'Incorrect answer. Try again.',
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result ?? false;
}

/// Phase 2 + 3: Create a new PIN (enter + confirm).
/// Returns the new PIN or null if cancelled.
Future<String?> _showCreatePinFlow(BuildContext context) async {
  // Phase 2: Enter new PIN
  final newPin = await _showPinEntryDialog(
    context,
    title: 'Set New PIN',
    subtitle: 'Enter a new 4-digit PIN',
  );
  if (newPin == null || !context.mounted) return null;

  // Phase 3: Confirm new PIN
  final confirmed = await _showPinEntryDialog(
    context,
    title: 'Confirm New PIN',
    subtitle: 'Enter the same PIN again',
  );
  if (confirmed == null || !context.mounted) return null;

  if (newPin != confirmed) {
    if (context.mounted) {
      // Retry the whole create flow
      return _showCreatePinFlow(context);
    }
    return null;
  }

  return newPin;
}

/// Shows a single PIN entry dialog. Returns the entered PIN or null.
Future<String?> _showPinEntryDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  final controller = TextEditingController();
  String? errorText;

  final result = await showSettledDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '····',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _popDialog(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = controller.text;
              if (RegExp(r'^\d{4}$').hasMatch(pin)) {
                _popDialog(ctx, pin);
              } else {
                setState(() => errorText = 'PIN must be exactly 4 digits');
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}
