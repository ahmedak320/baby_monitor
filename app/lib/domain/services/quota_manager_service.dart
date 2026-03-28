import '../../data/datasources/local/preferences_cache.dart';

/// Budget buckets for YouTube API quota allocation.
enum QuotaBucket {
  search(3000),
  related(2000),
  discovery(3000),
  details(1500),
  reserve(500);

  final int limit;
  const QuotaBucket(this.limit);
}

/// Tracks daily YouTube API quota usage and decides when to
/// fall back to Piped API to avoid exhaustion.
/// YouTube Data API v3: 10,000 units/day.
class QuotaManagerService {
  QuotaManagerService._();

  static const int _dailyLimit = 10000;

  /// Check if we can spend [cost] units from [bucket].
  static bool canUseQuota(QuotaBucket bucket, int cost) {
    _resetIfNewDay();
    final used = _getBucketUsage(bucket);
    return used + cost <= bucket.limit;
  }

  /// Record [cost] units spent from [bucket].
  static Future<void> useQuota(QuotaBucket bucket, int cost) async {
    _resetIfNewDay();
    final used = _getBucketUsage(bucket);
    await PreferencesCache.setQuotaUsage(bucket.name, used + cost);
    final totalUsed = _getTotalUsage() + cost;
    await PreferencesCache.setQuotaUsage('total', totalUsed);
  }

  /// Whether we should use Piped API instead for [bucket].
  static bool shouldUsePiped(QuotaBucket bucket) {
    _resetIfNewDay();
    final used = _getBucketUsage(bucket);
    final totalUsed = _getTotalUsage();
    // Use Piped if bucket is 80%+ consumed or total is 90%+ consumed
    return used >= bucket.limit * 0.8 || totalUsed >= _dailyLimit * 0.9;
  }

  /// Get remaining units for the day.
  static int get remainingDaily {
    _resetIfNewDay();
    return _dailyLimit - _getTotalUsage();
  }

  /// Get usage for a specific bucket.
  static int getBucketUsage(QuotaBucket bucket) {
    _resetIfNewDay();
    return _getBucketUsage(bucket);
  }

  /// Get total daily usage.
  static int get totalUsage {
    _resetIfNewDay();
    return _getTotalUsage();
  }

  // --- Internal ---

  static int _getBucketUsage(QuotaBucket bucket) =>
      PreferencesCache.getQuotaUsage(bucket.name);

  static int _getTotalUsage() => PreferencesCache.getQuotaUsage('total');

  static void _resetIfNewDay() {
    final today = DateTime.now().toIso8601String().split('T').first;
    final lastReset = PreferencesCache.getQuotaResetDate();
    if (lastReset != today) {
      // New day — reset all buckets
      for (final bucket in QuotaBucket.values) {
        PreferencesCache.setQuotaUsage(bucket.name, 0);
      }
      PreferencesCache.setQuotaUsage('total', 0);
      PreferencesCache.setQuotaResetDate(today);
    }
  }
}
