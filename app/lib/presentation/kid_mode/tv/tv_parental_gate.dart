import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme/kid_theme.dart';
import 'tv_pin_pad.dart';

/// Persistent lockout tracker for the TV parental gate.
/// Prevents brute-force bypassing by maintaining state across dialog re-opens.
class _GateLockout {
  static int _totalAttempts = 0;
  static DateTime? _lockedUntil;

  static bool get isLocked {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      _totalAttempts = 0;
      return false;
    }
    return true;
  }

  static Duration get remainingLockout {
    if (_lockedUntil == null) return Duration.zero;
    final remaining = _lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static void recordFailure() {
    _totalAttempts++;
    if (_totalAttempts >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(minutes: 5));
    }
  }

  static void reset() {
    _totalAttempts = 0;
    _lockedUntil = null;
  }
}

/// TV-friendly parental gate using a math problem with the TV PIN pad.
class TvParentalGate extends StatefulWidget {
  const TvParentalGate({super.key});

  /// Show the TV parental gate dialog. Returns true if passed.
  static Future<bool> show(BuildContext context) async {
    if (_GateLockout.isLocked) {
      final remaining = _GateLockout.remainingLockout.inMinutes + 1;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again in $remaining minutes.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TvParentalGate(),
    );
    return result ?? false;
  }

  @override
  State<TvParentalGate> createState() => _TvParentalGateState();
}

class _TvParentalGateState extends State<TvParentalGate> {
  late int _a, _b, _answer;
  String? _error;
  int _dialogAttempts = 0;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final rng = Random();
    // Use multiplication for harder problems (result always 3 digits)
    _a = rng.nextInt(8) + 12; // 12-19
    _b = rng.nextInt(8) + 12; // 12-19
    _answer = _a * _b; // Range: 144-361, always 3 digits
    _error = null;
  }

  void _checkAnswer(String input) {
    final parsed = int.tryParse(input);
    if (parsed == _answer) {
      _GateLockout.reset();
      Navigator.of(context).pop(true);
    } else {
      _dialogAttempts++;
      _GateLockout.recordFailure();
      if (_dialogAttempts >= 3 || _GateLockout.isLocked) {
        Navigator.of(context).pop(false);
      } else {
        setState(() {
          _error = 'Incorrect. Try again.';
          _generateProblem();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KidTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Parent Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: KidTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What is $_a \u00d7 $_b?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: KidTheme.youtubeRed,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            TvPinPad(
              pinLength:
                  3, // Fixed length — never reveals the answer digit count
              onSubmit: _checkAnswer,
              onCancel: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
