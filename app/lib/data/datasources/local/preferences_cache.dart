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
}
