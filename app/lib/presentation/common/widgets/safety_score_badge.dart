import 'package:flutter/material.dart';

/// Badge showing a safety score with color coding.
class SafetyScoreBadge extends StatelessWidget {
  final double score; // 1-10
  final String label;

  const SafetyScoreBadge({super.key, required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _colorForScore(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Color _colorForScore(double s) {
    if (s <= 3) return Colors.green;
    if (s <= 6) return Colors.orange;
    return Colors.red;
  }
}
