import 'package:flutter/material.dart';

/// Banner shown at the top of kid mode when time is almost up.
class WinddownBanner extends StatelessWidget {
  final int minutesRemaining;

  const WinddownBanner({super.key, required this.minutesRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            minutesRemaining > 1
                ? '$minutesRemaining minutes left!'
                : 'Almost time to stop!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
