import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/subscription_repository.dart';
import '../../../providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subAsync.when(
        data: (sub) {
          final isPremium = sub?.isPremium ?? false;
          final used = sub?.monthlyAnalysesUsed ?? 0;
          final limit = sub?.monthlyAnalysesLimit ?? 50;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current plan card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        isPremium ? Icons.star : Icons.star_border,
                        size: 48,
                        color: isPremium ? Colors.amber : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPremium ? 'Premium Plan' : 'Free Plan',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(height: 16),
                        Text('$used / $limit analyses used this month'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (used / limit).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Premium features comparison
              if (!isPremium) ...[
                const Text(
                  'Upgrade to Premium',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _FeatureCompare(
                  feature: 'Video analyses',
                  free: '$limit/month',
                  premium: 'Unlimited',
                ),
                _FeatureCompare(
                  feature: 'Child profiles',
                  free: '1',
                  premium: 'Unlimited',
                ),
                _FeatureCompare(
                  feature: 'Screen time',
                  free: 'Basic limits',
                  premium: 'Full controls',
                ),
                _FeatureCompare(
                  feature: 'Content scheduling',
                  free: '-',
                  premium: 'Yes',
                ),
                _FeatureCompare(
                  feature: 'Offline playlists',
                  free: '-',
                  premium: 'Yes',
                ),
                _FeatureCompare(
                  feature: 'Priority analysis',
                  free: '-',
                  premium: 'Yes',
                ),

                const SizedBox(height: 24),

                // Upgrade button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final repo = SubscriptionRepository();
                      await repo.updateTier(SubscriptionTier.premium);
                      ref.invalidate(subscriptionProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Upgraded to Premium! Enjoy all features.',
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Upgrade for \$4.99/month',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cancel anytime. 7-day free trial.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          'You have full access to all features!',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Something went wrong. Please try again.'),
        ),
      ),
    );
  }
}

class _FeatureCompare extends StatelessWidget {
  final String feature;
  final String free;
  final String premium;

  const _FeatureCompare({
    required this.feature,
    required this.free,
    required this.premium,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              premium,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
