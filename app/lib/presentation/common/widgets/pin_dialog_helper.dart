import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/services/parental_control_service.dart';

// Brute-force protection state (shared across all PIN dialogs)
int _pinAttempts = 0;
DateTime? _lockoutUntil;
int _lockoutDurationSeconds = 30;
const int _maxPinAttempts = 5;

void _resetPinCounters() {
  _pinAttempts = 0;
  _lockoutUntil = null;
  _lockoutDurationSeconds = 30;
}

/// Show the full PIN authentication flow.
///
/// If no PIN is set, prompts the user to create one and returns true.
/// Includes "Forgot PIN?" which presents a math problem then lets the
/// user set a new PIN.
Future<bool> showPinAuthDialog(BuildContext context) async {
  final hasPin = await ParentalControlService.hasPin();
  if (!hasPin) {
    if (!context.mounted) return false;
    return _showSetPinDialog(context, isInitial: true);
  }
  if (!context.mounted) return false;
  return _showVerifyPinDialog(context);
}

/// PIN verification dialog with brute-force protection and "Forgot PIN?".
Future<bool> _showVerifyPinDialog(BuildContext context) async {
  // Check lockout
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
            autofocus: true,
            decoration: const InputDecoration(hintText: '4-digit PIN'),
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
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Will trigger forgot-PIN flow after dialog closes
          },
          child: const Text('Forgot PIN?'),
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
                  _lockoutUntil = DateTime.now().add(
                    Duration(seconds: _lockoutDurationSeconds),
                  );
                  _lockoutDurationSeconds = min(
                    _lockoutDurationSeconds * 2,
                    3600,
                  );
                  _pinAttempts = 0;
                  if (ctx.mounted) {
                    Navigator.pop(ctx, false);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Too many failed attempts. Locked for '
                          '$_lockoutDurationSeconds seconds.',
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

  // If result is null, "Forgot PIN?" was tapped — start forgot flow.
  // Delay one event-loop tick so Flutter finishes disposing the previous
  // dialog's widget tree before we open a new one (avoids
  // "dependents.isEmpty is not true" assertion).
  if (result == null) {
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return false;
    return _showForgotPinFlow(context);
  }
  return result;
}

/// Forgot PIN flow: math problem → set new PIN → authenticated.
Future<bool> _showForgotPinFlow(BuildContext context) async {
  final problem = ParentalControlService.generateMathProblem();
  final answerController = TextEditingController();

  final solved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Verify You\'re a Parent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Solve this math problem to reset your PIN:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            '${problem.question} = ?',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: answerController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Your answer',
              border: OutlineInputBorder(),
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
          onPressed: () {
            final input = int.tryParse(answerController.text);
            if (input == problem.answer) {
              Navigator.pop(ctx, true);
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Incorrect answer. Try again.')),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
  answerController.dispose();

  if (solved != true || !context.mounted) return false;

  // Wait for the math-problem dialog to fully dispose before opening the
  // set-PIN dialog (same disposal-race guard as above).
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) return false;

  // Math solved — let them set a new PIN
  final pinSet = await _showSetPinDialog(context, isInitial: false);
  if (pinSet) _resetPinCounters();
  return pinSet;
}

/// Dialog to set (or reset) a 4-digit PIN.
///
/// [isInitial] controls the title text: "Set a Parent PIN" vs "Set New PIN".
/// Returns true if the PIN was successfully saved.
Future<bool> _showSetPinDialog(
  BuildContext context, {
  required bool isInitial,
}) async {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  String? errorText;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(isInitial ? 'Set a Parent PIN' : 'Set New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isInitial
                  ? 'Choose a 4-digit PIN to protect kid mode.'
                  : 'Enter your new 4-digit PIN.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'New PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: 'Confirm PIN',
                border: OutlineInputBorder(),
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
          if (!isInitial)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              final confirm = confirmController.text;

              if (pin.length != 4) {
                setState(() => errorText = 'PIN must be 4 digits');
                return;
              }
              if (pin != confirm) {
                setState(() => errorText = 'PINs do not match');
                return;
              }

              await ParentalControlService.setPin(pin);
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    ),
  );
  pinController.dispose();
  confirmController.dispose();
  return result ?? false;
}
