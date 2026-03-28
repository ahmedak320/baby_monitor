import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_metadata.dart';
import '../../../data/datasources/remote/supabase_client.dart';
import '../../../domain/services/analytics_service.dart';

/// Categories for beta feedback.
const _feedbackCategories = {
  'bug': ('Bug Report', Icons.bug_report, 'Something isn\'t working right'),
  'feature_request': (
    'Feature Request',
    Icons.lightbulb,
    'I wish the app could...',
  ),
  'content_issue': (
    'Content Issue',
    Icons.shield,
    'A video was incorrectly filtered',
  ),
  'usability': ('Usability', Icons.touch_app, 'Something is hard to use'),
  'general': ('General Feedback', Icons.chat, 'Any other thoughts'),
};

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  String _selectedCategory = 'general';
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _submitting = true);

    try {
      final userId = SupabaseClientWrapper.currentUserId;
      await SupabaseClientWrapper.client.from('beta_feedback').insert({
        'parent_id': userId,
        'category': _selectedCategory,
        'message': message,
        'app_version': AppMetadata.appVersion,
      });

      AnalyticsService.trackFeedbackSubmitted(_selectedCategory);

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Help us improve Baby Monitor!',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Your feedback helps us make the app better for families.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Category selection
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feedbackCategories.entries.map((entry) {
              final isSelected = _selectedCategory == entry.key;
              final (label, icon, _) = entry.value;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 4),
                    Text(label),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _selectedCategory = entry.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _feedbackCategories[_selectedCategory]!.$3,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          // Message
          TextField(
            controller: _messageController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Tell us what\'s on your mind...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
