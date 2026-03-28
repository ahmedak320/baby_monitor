import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart';

/// TV platform type.
enum TvPlatform { androidTV, fireTV, none }

/// Platform detection utility for TV vs mobile.
class PlatformInfo {
  PlatformInfo._();

  static bool _initialized = false;
  static bool _isTV = false;
  static TvPlatform _tvPlatform = TvPlatform.none;

  // Test override
  static bool? _testIsTV;
  static TvPlatform? _testTvPlatform;

  static const _channel = MethodChannel('com.babymonitor/platform');

  /// Initialize platform detection. Call once at app startup.
  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      final result = await _channel.invokeMethod<Map>('getPlatformInfo');
      if (result != null) {
        _isTV = result['isTV'] as bool? ?? false;
        final isFireTV = result['isFireTV'] as bool? ?? false;
        if (_isTV) {
          _tvPlatform = isFireTV ? TvPlatform.fireTV : TvPlatform.androidTV;
        }
      }
    } on MissingPluginException catch (_) {
      // Platform channel not registered (e.g., running on iOS or tests)
    } on PlatformException catch (_) {
      // Platform method call failed
    }

    _initialized = true;
  }

  /// Whether the app is running on a TV device.
  static bool get isTV => _testIsTV ?? _isTV;

  /// Whether the app is running on a mobile/tablet device.
  static bool get isMobile => !isTV;

  /// The specific TV platform, or [TvPlatform.none] for mobile.
  static TvPlatform get tvPlatform => _testTvPlatform ?? _tvPlatform;

  /// Override for widget tests. Only available in debug/test builds.
  static void overrideForTest({bool? isTV, TvPlatform? tvPlatform}) {
    assert(kDebugMode, 'overrideForTest must only be called in debug mode');
    _testIsTV = isTV;
    _testTvPlatform = tvPlatform;
  }

  /// Clear test overrides. Only available in debug/test builds.
  static void clearTestOverride() {
    assert(kDebugMode, 'clearTestOverride must only be called in debug mode');
    _testIsTV = null;
    _testTvPlatform = null;
  }
}
