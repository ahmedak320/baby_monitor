import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/services/parental_control_service.dart';
import '../../../utils/biometric_helper.dart';
import 'pin_reset_dialog.dart';

/// Widget that triggers biometric/PIN authentication for switching children.
/// Falls back to a simple PIN dialog if biometrics are unavailable.
/// Includes brute-force protection with exponential lockout.
class BiometricSwitch extends StatelessWidget {
  final VoidCallback onAuthenticated;
  final Widget child;

  const BiometricSwitch({
    super.key,
    required this.onAuthenticated,
    required this.child,
  });

  /// Track consecutive failed PIN attempts.
  static int _pinAttempts = 0;

  /// When the lockout expires (null means no lockout).
  static DateTime? _lockoutUntil;

  /// Current lockout duration in seconds (doubles each lockout, max 1 hour).
  static int _lockoutDurationSeconds = 30;

  /// Max attempts before lockout kicks in.
  static const int _maxAttempts = 5;

  /// Reset counters on successful authentication.
  static void _resetCounters() {
    _pinAttempts = 0;
    _lockoutUntil = null;
    _lockoutDurationSeconds = 30;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => _authenticate(context), child: child);
  }

  Future<void> _authenticate(BuildContext context) async {
    // Check lockout before proceeding
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
      return;
    }

    final bioAvailable = await BiometricHelper.isAvailable;

    if (bioAvailable) {
      final success = await BiometricHelper.authenticateForChildSwitch();
      if (success) {
        _resetCounters();
        onAuthenticated();
        return;
      }
    }

    // Biometric failed or unavailable — fall back to PIN dialog
    if (context.mounted) {
      final passed = await _showPinDialog(context);
      if (passed) {
        _resetCounters();
        onAuthenticated();
      }
    }
  }

  Future<bool> _showPinDialog(BuildContext context) async {
    // Re-check lockout (could have been set during a previous dialog)
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
    String? errorText;
    bool isVerifying = false;

    final result = await showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final remainingAttempts = _maxAttempts - _pinAttempts;
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
                if (remainingAttempts < _maxAttempts)
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
                        Navigator.pop(dialogCtx, false);
                      },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isVerifying
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(dialogCtx, 'forgot');
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
                          verified = await ParentalControlService.verifyPin(
                            pin,
                          );
                        } catch (e) {
                          if (!dialogCtx.mounted) return;
                          setDialogState(() {
                            isVerifying = false;
                            errorText =
                                'Verification failed. Please try again.';
                          });
                          return;
                        }

                        if (!dialogCtx.mounted) return;

                        if (verified) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(dialogCtx, true);
                        } else {
                          _pinAttempts++;
                          if (_pinAttempts >= _maxAttempts) {
                            _lockoutUntil = DateTime.now().add(
                              Duration(seconds: _lockoutDurationSeconds),
                            );
                            _lockoutDurationSeconds = min(
                              _lockoutDurationSeconds * 2,
                              3600,
                            );
                            _pinAttempts = 0;
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(dialogCtx, false);
                          } else {
                            controller.clear();
                            setDialogState(() {
                              isVerifying = false;
                              errorText =
                                  'Incorrect PIN. '
                                  '${_maxAttempts - _pinAttempts} '
                                  'attempts remaining.';
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
}
