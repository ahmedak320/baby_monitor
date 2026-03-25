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
}
