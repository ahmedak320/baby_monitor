import 'package:flutter/material.dart';

/// Subtle screen time remaining indicator shown in kid mode.
class ScreenTimeIndicator extends StatelessWidget {
  final int? minutesRemaining; // null = no limit

  const ScreenTimeIndicator({super.key, this.minutesRemaining});

  @override
  Widget build(BuildContext context) {
    if (minutesRemaining == null) return const SizedBox.shrink();

    final color = minutesRemaining! <= 5
        ? Colors.red
        : minutesRemaining! <= 15
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${minutesRemaining}m',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
