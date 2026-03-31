import 'dart:math';

import 'package:flutter/material.dart';

/// Parental gate that requires solving a math problem to exit kid mode.
/// Uses age-appropriate math problems.
class ParentalGate extends StatefulWidget {
  final VoidCallback onPassed;
  final VoidCallback onCancelled;
  final int childAge;

  const ParentalGate({
    super.key,
    required this.onPassed,
    required this.onCancelled,
    this.childAge = 5,
  });

  @override
  State<ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<ParentalGate> {
  late int _num1;
  late int _num2;
  late int _correctAnswer;
  late String _operation;
  final _answerController = TextEditingController();
  String? _error;

  /// Track attempts across dialog re-opens to prevent bypass by cancelling.
  static int _attempts = 0;

  /// Cooldown after 3 failed attempts (30 seconds).
  static DateTime? _cooldownUntil;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final random = Random();
    final age = widget.childAge;

    if (age >= 10) {
      // Multiplication: 10-29 x 10-29
      _num1 = 10 + random.nextInt(20);
      _num2 = 10 + random.nextInt(20);
      _correctAnswer = _num1 * _num2;
      _operation = '\u00d7'; // multiplication sign
    } else if (age >= 7) {
      // Three-digit addition: 100-499 + 100-499
      _num1 = 100 + random.nextInt(400);
      _num2 = 100 + random.nextInt(400);
      _correctAnswer = _num1 + _num2;
      _operation = '+';
    } else {
      // Two-digit addition (default for young kids)
      _num1 = 10 + random.nextInt(30);
      _num2 = 10 + random.nextInt(30);
      _correctAnswer = _num1 + _num2;
      _operation = '+';
    }

    _answerController.clear();
    _error = null;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Parent Verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Solve this to continue:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              '$_num1 $_operation $_num2 = ?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                hintText: 'Answer',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _checkAnswer(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancelled,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkAnswer,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _checkAnswer() {
    // Check cooldown
    if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
      final remaining = _cooldownUntil!.difference(DateTime.now()).inSeconds;
      setState(() {
        _error = 'Please wait $remaining seconds before trying again.';
      });
      return;
    }

    final answer = int.tryParse(_answerController.text.trim());
    if (answer == _correctAnswer) {
      _cooldownUntil = null;
      _attempts = 0;
      widget.onPassed();
    } else {
      _attempts++;
      if (_attempts >= 3) {
        // Apply 30-second cooldown and generate new problem
        _cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
        setState(() {
          _generateProblem();
          _error = 'Too many wrong answers. Wait 30 seconds for a new problem.';
          _attempts = 0;
        });
      } else {
        setState(() {
          _error = 'Incorrect. ${3 - _attempts} attempts remaining.';
          _answerController.clear();
        });
      }
    }
  }
}

/// Shows the parental gate dialog and returns true if passed.
Future<bool> showParentalGate(BuildContext context, {int childAge = 5}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ParentalGate(
      childAge: childAge,
      onPassed: () => Navigator.of(context).pop(true),
      onCancelled: () => Navigator.of(context).pop(false),
    ),
  ).then((value) => value ?? false);
}
