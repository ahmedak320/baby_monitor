import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/supabase_client.dart';

/// Screen for community rating and reporting video analysis accuracy.
class ReportContentScreen extends ConsumerStatefulWidget {
  final String videoId;
  final String videoTitle;

  const ReportContentScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  ConsumerState<ReportContentScreen> createState() =>
      _ReportContentScreenState();
}

class _ReportContentScreenState extends ConsumerState<ReportContentScreen> {
  String? _selectedRating;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  static const _ratingOptions = [
    _RatingOption(
      value: 'accurate',
      label: 'Accurate',
      description: 'The analysis correctly identified this content',
      icon: Icons.check_circle,
      color: Colors.green,
    ),
    _RatingOption(
      value: 'too_strict',
      label: 'Too Strict',
      description: 'This content is safe but was blocked or scored harshly',
      icon: Icons.shield,
      color: Colors.orange,
    ),
    _RatingOption(
      value: 'too_lenient',
      label: 'Too Lenient',
      description: 'This content should have been filtered more strictly',
      icon: Icons.warning,
      color: Colors.deepOrange,
    ),
    _RatingOption(
      value: 'dangerous',
      label: 'Dangerous Content',
      description: 'This content is harmful and should be globally blocked',
      icon: Icons.dangerous,
      color: Colors.red,
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Video info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.videoTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'How accurate was our analysis?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps improve filtering for all parents.',
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 16),

          // Rating options
          for (final option in _ratingOptions)
            _RatingTile(
              option: option,
              isSelected: _selectedRating == option.value,
              onTap: () => setState(() => _selectedRating = option.value),
            ),

          const SizedBox(height: 16),

          // Optional comment
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Additional comments (optional)',
              hintText: 'What specifically was wrong?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // Submit
          ElevatedButton(
            onPressed: _selectedRating != null && !_isSubmitting
                ? _submit
                : null,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Rating'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null || _selectedRating == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Upsert community rating
      await SupabaseClientWrapper.client.from('community_ratings').upsert(
        {
          'video_id': widget.videoId,
          'parent_id': userId,
          'rating': _selectedRating,
          'comment': _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
        },
        onConflict: 'video_id,parent_id',
      );

      // If "dangerous", also flag for global blacklist
      if (_selectedRating == 'dangerous') {
        await SupabaseClientWrapper.client.from('video_analyses').update({
          'is_globally_blacklisted': true,
          'blacklist_reason': 'Reported by community: ${_commentController.text.trim()}',
        }).eq('video_id', widget.videoId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your rating helps other parents.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _RatingOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _RatingOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _RatingTile extends StatelessWidget {
  final _RatingOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RatingTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: option.color, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? option.color.withValues(alpha: 0.05) : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(option.icon, color: option.color),
        title: Text(
          option.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          option.description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: option.color)
            : const Icon(Icons.circle_outlined, color: Colors.grey),
      ),
    );
  }
}
