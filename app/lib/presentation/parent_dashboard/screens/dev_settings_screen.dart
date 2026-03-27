import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/local/preferences_cache.dart';
import '../../../data/repositories/subscription_repository.dart';
import '../../../providers/subscription_provider.dart';

/// Developer settings screen for testing. Only accessible in debug mode
/// via 7-tap on version number in About screen.
class DevSettingsScreen extends ConsumerStatefulWidget {
  const DevSettingsScreen({super.key});

  @override
  ConsumerState<DevSettingsScreen> createState() => _DevSettingsScreenState();
}

class _DevSettingsScreenState extends ConsumerState<DevSettingsScreen> {
  final _subRepo = SubscriptionRepository();
  bool _skipBiometric = PreferencesCache.skipBiometricAuth;
  String _aiProvider = PreferencesCache.aiProvider;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Settings'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These settings are for testing only and will not appear in production builds.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Subscription Tier
          const Text(
            'Subscription',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          subscriptionAsync.when(
            data: (sub) {
              final isPremium = sub?.isPremium ?? false;
              return Column(
                children: [
                  _DevSettingsTile(
                    icon: Icons.star,
                    title: 'Subscription Tier',
                    subtitle:
                        'Current: ${isPremium ? "Premium" : "Free"}',
                    trailing: Switch(
                      value: isPremium,
                      onChanged: _isLoading
                          ? null
                          : (value) => _toggleTier(value),
                    ),
                  ),
                  _DevSettingsTile(
                    icon: Icons.refresh,
                    title: 'Reset Analysis Count',
                    subtitle:
                        'Used: ${sub?.monthlyAnalysesUsed ?? 0} / ${sub?.monthlyAnalysesLimit ?? 50}',
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : _resetAnalysisCount,
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),

          const Divider(height: 32),

          // AI Provider
          const Text(
            'AI Provider',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _DevSettingsTile(
            icon: Icons.smart_toy,
            title: 'Analysis Provider',
            subtitle: 'Current: $_aiProvider',
            trailing: DropdownButton<String>(
              value: _aiProvider,
              items: const [
                DropdownMenuItem(value: 'claude', child: Text('Claude')),
                DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                DropdownMenuItem(value: 'local', child: Text('Local')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await PreferencesCache.setAiProvider(value);
                setState(() => _aiProvider = value);
              },
            ),
          ),

          const Divider(height: 32),

          // Auth
          const Text(
            'Authentication',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _DevSettingsTile(
            icon: Icons.fingerprint,
            title: 'Skip Biometric Auth',
            subtitle: 'Bypass biometric gates during testing',
            trailing: Switch(
              value: _skipBiometric,
              onChanged: (value) async {
                await PreferencesCache.setSkipBiometricAuth(value);
                setState(() => _skipBiometric = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTier(bool premium) async {
    setState(() => _isLoading = true);
    try {
      await _subRepo.updateTier(
        premium ? SubscriptionTier.premium : SubscriptionTier.free,
      );
      ref.invalidate(subscriptionProvider);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetAnalysisCount() async {
    setState(() => _isLoading = true);
    try {
      await _subRepo.resetAnalysisCount();
      ref.invalidate(subscriptionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis count reset to 0')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _DevSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _DevSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
