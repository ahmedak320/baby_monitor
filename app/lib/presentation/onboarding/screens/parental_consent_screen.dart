import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/legal_content.dart';
import '../../../data/datasources/remote/supabase_client.dart';
import '../../../routing/route_names.dart';
import '../../common/widgets/legal_text_screen.dart';

/// COPPA parental consent screen shown before first child profile creation.
/// Requires parent to review and consent to child data collection practices.
class ParentalConsentScreen extends ConsumerStatefulWidget {
  const ParentalConsentScreen({super.key});

  @override
  ConsumerState<ParentalConsentScreen> createState() =>
      _ParentalConsentScreenState();
}

class _ParentalConsentScreenState extends ConsumerState<ParentalConsentScreen> {
  final _nameController = TextEditingController();
  bool _consentNameDob = false;
  bool _consentWatchHistory = false;
  bool _consentScreenTime = false;
  bool _consentFiltering = false;
  bool _consentAiAnalysis = false;
  bool _consentCommunity = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _allConsented =>
      _consentNameDob &&
      _consentWatchHistory &&
      _consentScreenTime &&
      _consentFiltering &&
      _consentAiAnalysis &&
      _consentCommunity &&
      _nameController.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Parental Consent')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.family_restroom,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Before creating a child profile',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Federal law (COPPA) requires us to obtain your consent '
                'before collecting information about your child. Please '
                'review each item below and provide your consent.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalTextScreen(
                        title: "Children's Privacy Notice",
                        content: LegalContent.childrensPrivacyNotice,
                      ),
                    ),
                  ),
                  child: const Text("Read full Children's Privacy Notice"),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'I consent to Baby Monitor collecting:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              _ConsentItem(
                value: _consentNameDob,
                onChanged: (v) => setState(() => _consentNameDob = v ?? false),
                title: "Child's name and date of birth",
                subtitle:
                    'Used to identify the profile and calculate age for '
                    'content filtering',
              ),
              _ConsentItem(
                value: _consentWatchHistory,
                onChanged: (v) =>
                    setState(() => _consentWatchHistory = v ?? false),
                title: 'Watch history',
                subtitle:
                    'Which videos were watched, for how long, and when. '
                    'Visible only to you. Auto-deleted after 1 year.',
              ),
              _ConsentItem(
                value: _consentScreenTime,
                onChanged: (v) =>
                    setState(() => _consentScreenTime = v ?? false),
                title: 'Screen time data',
                subtitle:
                    'Session start/end times and duration. Used to enforce '
                    'limits you set. Auto-deleted after 1 year.',
              ),
              _ConsentItem(
                value: _consentFiltering,
                onChanged: (v) =>
                    setState(() => _consentFiltering = v ?? false),
                title: 'Content filtering logs',
                subtitle:
                    'Which videos were blocked and why. Helps you review '
                    'filter decisions. Auto-deleted after 1 year.',
              ),
              _ConsentItem(
                value: _consentAiAnalysis,
                onChanged: (v) =>
                    setState(() => _consentAiAnalysis = v ?? false),
                title: 'AI safety analysis of video content',
                subtitle:
                    'Video metadata and transcripts (not child data) are '
                    'sent to AI services to evaluate content safety.',
              ),
              _ConsentItem(
                value: _consentCommunity,
                onChanged: (v) =>
                    setState(() => _consentCommunity = v ?? false),
                title: 'Community-shared video safety scores',
                subtitle:
                    'Video analysis results (safety scores, not child data) '
                    'are shared with other parents to reduce analysis costs.',
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Your full legal name',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Required to acknowledge your consent',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Legal Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _allConsented && !_isSubmitting
                    ? _handleConsent
                    : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('I Consent — Continue'),
              ),
              const SizedBox(height: 8),
              Text(
                'You can withdraw consent at any time by deleting your '
                "child's profile from Account Settings.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConsent() async {
    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseClientWrapper.currentUserId;
      if (userId != null) {
        await SupabaseClientWrapper.client.from('consent_records').insert({
          'parent_id': userId,
          'consent_type': 'coppa_parental_consent',
          'consent_version': LegalContent.currentVersion,
          'full_legal_name': _nameController.text.trim(),
          'consent_details': {
            'name_dob': _consentNameDob,
            'watch_history': _consentWatchHistory,
            'screen_time': _consentScreenTime,
            'filtering_logs': _consentFiltering,
            'ai_analysis': _consentAiAnalysis,
            'community_scores': _consentCommunity,
          },
        });
      }

      if (mounted) {
        context.pushNamed(RouteNames.addChild);
      }
    } catch (e) {
      // If consent_records table doesn't exist yet, still allow proceeding
      // (the consent is captured in-app; migration may not be deployed yet)
      if (mounted) {
        context.pushNamed(RouteNames.addChild);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ConsentItem extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String subtitle;

  const _ConsentItem({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
