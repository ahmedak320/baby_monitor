import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Central Hive cache manager with AES encryption.
class LocalCache {
  static const _approvedVideosBox = 'approved_videos';
  static const _preferencesBox = 'preferences';
  static const _thumbnailCacheBox = 'thumbnail_cache';
  static const _encryptionKeyName = 'hive_encryption_key';

  static late Box<Map> _approvedVideos;
  static late Box _preferences;
  static late Box<String> _thumbnailCache;

  /// Get or generate an AES encryption cipher backed by FlutterSecureStorage.
  static Future<HiveAesCipher> _getCipher() async {
    const secureStorage = FlutterSecureStorage();
    final existingKey = await secureStorage.read(key: _encryptionKeyName);

    final Uint8List keyBytes;
    if (existingKey != null) {
      keyBytes = base64Url.decode(existingKey);
    } else {
      keyBytes = Hive.generateSecureKey() as Uint8List;
      await secureStorage.write(
        key: _encryptionKeyName,
        value: base64Url.encode(keyBytes),
      );
    }

    return HiveAesCipher(keyBytes);
  }

  /// Open a Hive box with encryption, migrating unencrypted boxes if needed.
  static Future<Box<T>> _openEncryptedBox<T>(
    String name,
    HiveAesCipher cipher,
  ) async {
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (_) {
      // Existing box is likely unencrypted — delete and reopen with encryption.
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Initialize all Hive boxes with encryption. Call once at app startup.
  static Future<void> initialize() async {
    final cipher = await _getCipher();

    _approvedVideos = await _openEncryptedBox<Map>(_approvedVideosBox, cipher);
    _preferences = await _openEncryptedBox(_preferencesBox, cipher);
    _thumbnailCache =
        await _openEncryptedBox<String>(_thumbnailCacheBox, cipher);
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
