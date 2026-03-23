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
  final _answerController = TextEditingController();
  String? _error;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final random = Random();
    // Adults can solve these easily, kids cannot
    _num1 = 10 + random.nextInt(30); // 10-39
    _num2 = 10 + random.nextInt(30); // 10-39
    _correctAnswer = _num1 + _num2;
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
              '$_num1 + $_num2 = ?',
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
    final answer = int.tryParse(_answerController.text.trim());
    if (answer == _correctAnswer) {
      widget.onPassed();
    } else {
      _attempts++;
      if (_attempts >= 3) {
        // Generate a new problem after 3 failed attempts
        setState(() {
          _generateProblem();
          _error = 'Wrong answer. Try a new problem.';
          _attempts = 0;
        });
      } else {
        setState(() {
          _error = 'Incorrect. Try again.';
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
