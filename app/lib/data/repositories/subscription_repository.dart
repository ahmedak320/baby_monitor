import '../datasources/remote/supabase_client.dart';

/// Subscription tier.
enum SubscriptionTier { free, premium }

/// Subscription data model.
class Subscription {
  final String id;
  final String parentId;
  final SubscriptionTier tier;
  final int monthlyAnalysesUsed;
  final int monthlyAnalysesLimit;

  const Subscription({
    required this.id,
    required this.parentId,
    required this.tier,
    required this.monthlyAnalysesUsed,
    required this.monthlyAnalysesLimit,
  });

  bool get isPremium => tier == SubscriptionTier.premium;
  bool get hasAnalysesRemaining => monthlyAnalysesUsed < monthlyAnalysesLimit;
  int get analysesRemaining => monthlyAnalysesLimit - monthlyAnalysesUsed;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      tier: json['tier'] == 'premium'
          ? SubscriptionTier.premium
          : SubscriptionTier.free,
      monthlyAnalysesUsed: json['monthly_analyses_used'] as int? ?? 0,
      monthlyAnalysesLimit: json['monthly_analyses_limit'] as int? ?? 50,
    );
  }
}

/// Repository for managing subscription data.
class SubscriptionRepository {
  final _client = SupabaseClientWrapper.client;

  /// Fetch the current user's subscription.
  Future<Subscription?> getSubscription() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('subscriptions')
        .select()
        .eq('parent_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Subscription.fromJson(response);
  }

  /// Increment the monthly analysis usage counter.
  Future<void> incrementAnalysisUsage() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    await _client.rpc('increment_analysis_usage', params: {
      'user_id': userId,
    });
  }

  /// Update the subscription tier (for dev/testing).
  Future<void> updateTier(SubscriptionTier tier) async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    final tierStr = tier == SubscriptionTier.premium ? 'premium' : 'free';
    final limit = tier == SubscriptionTier.premium ? 999999 : 50;

    await _client.from('subscriptions').update({
      'tier': tierStr,
      'monthly_analyses_limit': limit,
    }).eq('parent_id', userId);
  }

  /// Reset the monthly analysis counter (for dev/testing).
  Future<void> resetAnalysisCount() async {
    final userId = SupabaseClientWrapper.currentUserId;
    if (userId == null) return;

    await _client.from('subscriptions').update({
      'monthly_analyses_used': 0,
    }).eq('parent_id', userId);
  }
}
