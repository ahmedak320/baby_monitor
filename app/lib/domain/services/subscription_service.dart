import 'package:flutter/material.dart';

import '../../data/repositories/subscription_repository.dart';

/// Service for checking subscription tier and gating premium features.
class SubscriptionService {
  final SubscriptionRepository _repo;

  SubscriptionService({SubscriptionRepository? repo})
      : _repo = repo ?? SubscriptionRepository();

  /// Check if user can perform an analysis (respects free tier limits).
  Future<bool> canAnalyze() async {
    final sub = await _repo.getSubscription();
    if (sub == null) return false;
    if (sub.isPremium) return true;
    return sub.hasAnalysesRemaining;
  }

  /// Check if user has premium access.
  Future<bool> isPremium() async {
    final sub = await _repo.getSubscription();
    return sub?.isPremium ?? false;
  }

  /// Increment usage after an analysis.
  Future<void> recordAnalysisUsage() async {
    await _repo.incrementAnalysisUsage();
  }

  /// Show upgrade prompt if not premium.
  static Future<bool> showUpgradePromptIfNeeded(
    BuildContext context, {
    required bool isPremium,
    required String feature,
  }) async {
    if (isPremium) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: Text(
          '$feature is available with Premium.\n\n'
          'Upgrade for \$4.99/month to unlock all features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
