import 'package:hive_flutter/hive_flutter.dart';

/// Central Hive cache manager.
class LocalCache {
  static const _approvedVideosBox = 'approved_videos';
  static const _preferencesBox = 'preferences';
  static const _thumbnailCacheBox = 'thumbnail_cache';

  static late Box<Map> _approvedVideos;
  static late Box _preferences;
  static late Box<String> _thumbnailCache;

  /// Initialize all Hive boxes. Call once at app startup.
  static Future<void> initialize() async {
    _approvedVideos = await Hive.openBox<Map>(_approvedVideosBox);
    _preferences = await Hive.openBox(_preferencesBox);
    _thumbnailCache = await Hive.openBox<String>(_thumbnailCacheBox);
  }

  static Box<Map> get approvedVideos => _approvedVideos;
  static Box get preferences => _preferences;
  static Box<String> get thumbnailCache => _thumbnailCache;

  /// Clear all cached data (e.g., on sign out).
  static Future<void> clearAll() async {
    await _approvedVideos.clear();
    await _preferences.clear();
    await _thumbnailCache.clear();
  }
}
