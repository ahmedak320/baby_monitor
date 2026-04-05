import 'local_cache.dart';

/// Local preferences cache for quick access without network calls.
class PreferencesCache {
  static const _lastChildIdKey = 'last_child_id';
  static const _kidModeActiveKey = 'kid_mode_active';
  static const _deviceIdKey = 'device_id';

  /// Get the last selected child ID.
  static String? get lastChildId =>
      LocalCache.preferences.get(_lastChildIdKey) as String?;

  /// Set the last selected child ID.
  static Future<void> setLastChildId(String childId) async {
    await LocalCache.preferences.put(_lastChildIdKey, childId);
  }

  /// Whether kid mode is currently active.
  static bool get isKidModeActive =>
      LocalCache.preferences.get(_kidModeActiveKey) as bool? ?? false;

  /// Set kid mode active state.
  static Future<void> setKidModeActive(bool active) async {
    await LocalCache.preferences.put(_kidModeActiveKey, active);
  }

  /// Get the persisted device ID.
  static String? get deviceId =>
      LocalCache.preferences.get(_deviceIdKey) as String?;

  /// Set the device ID.
  static Future<void> setDeviceId(String id) async {
    await LocalCache.preferences.put(_deviceIdKey, id);
  }

  /// Get the stored age bracket label for a child.
  static String? getChildBracket(String childId) =>
      LocalCache.preferences.get('child_bracket_$childId') as String?;

  /// Set the age bracket label for a child.
  static Future<void> setChildBracket(String childId, String bracket) async {
    await LocalCache.preferences.put('child_bracket_$childId', bracket);
  }

  /// Get the last time age transition was dismissed for a child.
  static String? getTransitionDismissed(String childId) =>
      LocalCache.preferences.get('transition_dismissed_$childId') as String?;

  /// Mark an age transition as dismissed.
  static Future<void> setTransitionDismissed(String childId) async {
    await LocalCache.preferences.put(
      'transition_dismissed_$childId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get the last date a notification type was shown.
  static String? getLastNotificationDate(String notificationType) =>
      LocalCache.preferences.get('notification_$notificationType') as String?;

  /// Set the last date a notification type was shown.
  static Future<void> setLastNotificationDate(
    String notificationType,
    String date,
  ) async {
    await LocalCache.preferences.put('notification_$notificationType', date);
  }

  /// Get quota usage for a bucket.
  static int getQuotaUsage(String bucket) =>
      (LocalCache.preferences.get('quota_$bucket') as int?) ?? 0;

  /// Set quota usage for a bucket.
  static Future<void> setQuotaUsage(String bucket, int value) async {
    await LocalCache.preferences.put('quota_$bucket', value);
  }

  /// Get the last quota reset date.
  static String? getQuotaResetDate() =>
      LocalCache.preferences.get('quota_reset_date') as String?;

  /// Set the quota reset date.
  static Future<void> setQuotaResetDate(String date) async {
    await LocalCache.preferences.put('quota_reset_date', date);
  }

  // --- YouTube API key quota tracking ---

  /// Get daily quota usage for a specific YouTube API key.
  static int getYtKeyUsage(String keyHash) =>
      (LocalCache.preferences.get('yt_key_$keyHash') as int?) ?? 0;

  /// Set daily quota usage for a specific YouTube API key.
  static Future<void> setYtKeyUsage(String keyHash, int value) async {
    await LocalCache.preferences.put('yt_key_$keyHash', value);
  }

  /// Get the last date YouTube key quotas were reset.
  static String? getYtKeyResetDate() =>
      LocalCache.preferences.get('yt_key_reset_date') as String?;

  /// Set the YouTube key quota reset date.
  static Future<void> setYtKeyResetDate(String date) async {
    await LocalCache.preferences.put('yt_key_reset_date', date);
  }

  // --- PIN lockout (shared across all parental gate widgets) ---

  static const _pinAttemptsKey = 'pin_lockout_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until';
  static const _lockoutDurationKey = 'pin_lockout_duration';
  static const int maxPinAttempts = 5;

  /// Current failed PIN attempts.
  static int get pinAttempts =>
      (LocalCache.preferences.get(_pinAttemptsKey) as int?) ?? 0;

  /// Increment failed PIN attempts. Returns true if lockout was triggered.
  static Future<bool> incrementPinAttempts() async {
    final attempts = pinAttempts + 1;
    await LocalCache.preferences.put(_pinAttemptsKey, attempts);
    if (attempts >= maxPinAttempts) {
      final duration = pinLockoutDurationSeconds;
      await LocalCache.preferences.put(
        _lockoutUntilKey,
        DateTime.now().add(Duration(seconds: duration)).millisecondsSinceEpoch,
      );
      // Double the lockout duration for next time (max 1 hour).
      await LocalCache.preferences.put(
        _lockoutDurationKey,
        (duration * 2).clamp(30, 3600),
      );
      await LocalCache.preferences.put(_pinAttemptsKey, 0);
      return true;
    }
    return false;
  }

  /// Reset PIN lockout counters on successful authentication.
  static Future<void> resetPinLockout() async {
    await LocalCache.preferences.put(_pinAttemptsKey, 0);
    await LocalCache.preferences.delete(_lockoutUntilKey);
    await LocalCache.preferences.put(_lockoutDurationKey, 30);
  }

  /// Whether the user is currently locked out.
  static bool get isPinLockedOut {
    final until = lockoutUntilEpochMs;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Remaining lockout seconds, or 0 if not locked out.
  static int get pinLockoutRemainingSeconds {
    final until = lockoutUntilEpochMs;
    if (until == null) return 0;
    final remaining = (until - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  /// Raw lockout-until epoch milliseconds.
  static int? get lockoutUntilEpochMs =>
      LocalCache.preferences.get(_lockoutUntilKey) as int?;

  /// Current lockout duration in seconds (doubles each lockout).
  static int get pinLockoutDurationSeconds =>
      (LocalCache.preferences.get(_lockoutDurationKey) as int?) ?? 30;

  // --- Analytics opt-in (GDPR compliant, defaults to false) ---

  static const _analyticsOptedInKey = 'analytics_opted_in';

  /// Whether the user has opted in to analytics collection.
  static bool get analyticsOptedIn =>
      LocalCache.preferences.get(_analyticsOptedInKey) as bool? ?? false;

  /// Set the analytics opt-in preference.
  static set analyticsOptedIn(bool value) {
    LocalCache.preferences.put(_analyticsOptedInKey, value);
  }

  // --- Dev/Test Mode settings ---

  /// Whether to skip biometric auth during testing.
  static bool get skipBiometricAuth =>
      LocalCache.preferences.get('dev_skip_biometric') as bool? ?? false;

  /// Set skip biometric auth flag.
  static Future<void> setSkipBiometricAuth(bool skip) async {
    await LocalCache.preferences.put('dev_skip_biometric', skip);
  }

  /// Get the selected AI provider name.
  static String get aiProvider =>
      LocalCache.preferences.get('dev_ai_provider') as String? ?? 'claude';

  /// Set the AI provider name.
  static Future<void> setAiProvider(String provider) async {
    await LocalCache.preferences.put('dev_ai_provider', provider);
  }
}
