import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/subscription_repository.dart';

/// Provides the subscription repository.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

/// Provides the current user's subscription.
final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getSubscription();
});

/// Whether the current user has a premium subscription.
final isPremiumProvider = FutureProvider<bool>((ref) async {
  final subscription = await ref.watch(subscriptionProvider.future);
  return subscription?.isPremium ?? false;
});
