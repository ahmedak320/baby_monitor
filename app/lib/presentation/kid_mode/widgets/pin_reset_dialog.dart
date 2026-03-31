import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/services/parental_control_service.dart';

/// Wait for the current frame to fully complete (build → layout → paint).
/// More reliable than [Future.delayed(Duration.zero)] for avoiding the
/// "dependents.isEmpty is not true" assertion when chaining dialogs.
Future<void> _waitForFrameCompletion() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
  return completer.future;
}

/// Shows a "Forgot PIN?" flow:
/// 1. Solve a math problem to prove you're an adult
/// 2. Enter a new 4-digit PIN
/// 3. Confirm the new PIN
/// Returns true if the PIN was successfully reset.
Future<bool> showPinResetFlow(BuildContext context) async {
  // Phase 1: Math problem
  final mathPassed = await _showMathChallenge(context);
  if (!mathPassed || !context.mounted) return false;

  await _waitForFrameCompletion();
  if (!context.mounted) return false;

  // Phase 2 + 3: Create and confirm new PIN
  final newPin = await _showCreatePinFlow(context);
  if (newPin == null || !context.mounted) return false;

  // Save the new PIN
  await ParentalControlService.setPin(newPin);
  return true;
}

/// Shows a dialog to create + confirm a new PIN (no math gate).
/// Used by "Forgot PIN?" (after math gate) and by first-time PIN setup.
/// Returns the new PIN string, or null if cancelled.
Future<String?> showCreatePinDialog(BuildContext context) {
  return _showCreatePinFlow(context);
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

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
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
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final answer = int.tryParse(controller.text.trim());
                  if (answer == problem.answer) {
                    Navigator.pop(ctx, true);
                  } else {
                    attempts++;
                    if (attempts >= 3) {
                      Navigator.pop(ctx, false);
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
          ),
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

  await _waitForFrameCompletion();
  if (!context.mounted) return null;

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
      await _waitForFrameCompletion();
      if (!context.mounted) return null;
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

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => PopScope(
        canPop: false,
        child: AlertDialog(
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
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = controller.text;
                if (pin.length == 4) {
                  Navigator.pop(ctx, pin);
                } else {
                  setState(() => errorText = 'PIN must be 4 digits');
                }
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return result;
}
