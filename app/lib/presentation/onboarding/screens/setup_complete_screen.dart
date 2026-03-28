import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../providers/onboarding_provider.dart';

class SetupCompleteScreen extends ConsumerWidget {
  const SetupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),
              Text(
                'All Set!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Here\'s what we\'ll do for ${state.childName}:',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.cake,
                        label: 'Age group',
                        value: state.childDob != null
                            ? AgeCalculator.ageBracket(state.childDob!)
                            : 'Unknown',
                      ),
                      const Divider(),
                      _SummaryRow(
                        icon: Icons.shield,
                        label: 'Top concern',
                        value: _formatPriority(
                          state.filterPriorities.firstOrNull ?? '',
                        ),
                      ),
                      const Divider(),
                      _SummaryRow(
                        icon: Icons.tv,
                        label: 'Approved channels',
                        value: '${state.approvedChannelIds.length} selected',
                      ),
                      const Divider(),
                      _SummaryRow(
                        icon: Icons.category,
                        label: 'Content types',
                        value:
                            '${state.contentPreferences.values.where((v) => v != "blocked").length} allowed',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'re preparing a safe feed now.\nThis may take a moment.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () => _finishSetup(context, ref),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Watching'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSetup(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(onboardingProvider.notifier)
        .completeOnboarding();
    if (success && context.mounted) {
      context.goNamed(RouteNames.dashboard);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _formatPriority(String key) {
    return switch (key) {
      'overstimulation' => 'Overstimulation',
      'brainrot' => 'Brainrot',
      'scariness' => 'Scary Content',
      'language' => 'Bad Language',
      'ads' => 'Ads & Commercial',
      _ => key,
    };
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
