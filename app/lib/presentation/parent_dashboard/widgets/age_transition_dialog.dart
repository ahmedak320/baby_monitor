import 'package:flutter/material.dart';

import '../../../domain/services/age_transition_service.dart';

/// Dialog shown when a child crosses an age bracket boundary.
class AgeTransitionDialog extends StatelessWidget {
  final AgeTransition transition;
  final VoidCallback onApplyDefaults;
  final VoidCallback onKeepCurrent;

  const AgeTransitionDialog({
    super.key,
    required this.transition,
    required this.onApplyDefaults,
    required this.onKeepCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Text('🎂 ', style: TextStyle(fontSize: 28)),
          Expanded(
            child: Text(
              '${transition.child.name} turned ${transition.newAge}!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content recommendations updated:',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          _BracketTransitionRow(
            label: 'From',
            bracket: transition.previousBracket.label,
            color: Colors.grey,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.arrow_downward, color: Colors.green, size: 20),
          ),
          _BracketTransitionRow(
            label: 'To',
            bracket: transition.newBracket.label,
            color: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 16),
          Text(
            'We suggest relaxing filters to match '
            '${transition.newBracket.label}-level content. '
            'You can review and adjust anytime in Filter Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          // Show key changes
          _ChangePreview(
            title: 'New content types',
            items: transition.newBracket.recommendedContentTypes,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onKeepCurrent,
          child: const Text('Keep Current Settings'),
        ),
        FilledButton(
          onPressed: onApplyDefaults,
          child: const Text('Apply Recommendations'),
        ),
      ],
    );
  }
}

class _BracketTransitionRow extends StatelessWidget {
  final String label;
  final String bracket;
  final Color color;

  const _BracketTransitionRow({
    required this.label,
    required this.bracket,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            bracket,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ChangePreview extends StatelessWidget {
  final String title;
  final List<String> items;

  const _ChangePreview({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items
              .map(
                (t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
