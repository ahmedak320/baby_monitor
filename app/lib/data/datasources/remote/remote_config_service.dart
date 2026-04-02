import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';

/// Fetches runtime configuration from Supabase `app_config` table.
///
/// Falls back to compile-time defaults ([SupabaseConfig]) if the table is
/// unreachable or missing.  Initialize once at app startup via
/// `RemoteConfigService.instance.initialize()`.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  bool _loaded = false;

  List<String> _youtubeApiKeys = [];
  List<String> _pipedInstances = [];

  /// All YouTube API keys (from remote config + compile-time fallback).
  List<String> get youtubeApiKeys => _youtubeApiKeys;

  /// All Piped instance URLs.
  List<String> get pipedInstances => _pipedInstances;

  /// Cache TTL for video metadata.
  Duration get videoTtl => const Duration(days: 7);

  /// Cache TTL for channel metadata.
  Duration get channelTtl => const Duration(days: 7);

  /// Whether remote config has been loaded (even if it fell back to defaults).
  bool get isLoaded => _loaded;

  /// Fetch config from Supabase.  Safe to call multiple times (no-op after first).
  Future<void> initialize() async {
    if (_loaded) return;

    // Build compile-time defaults first.
    _youtubeApiKeys = _buildDefaultKeys();
    _pipedInstances = _buildDefaultPipedInstances();

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_config')
          .select('key, value')
          .limit(20);

      final rows = response as List<dynamic>;
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'];
        if (key == null || value == null) continue;

        switch (key) {
          case 'youtube_api_keys':
            final keys = _parseStringList(value);
            if (keys.isNotEmpty) _youtubeApiKeys = keys;
          case 'piped_instances':
            final instances = _parseStringList(value);
            if (instances.isNotEmpty) _pipedInstances = instances;
        }
      }

      // Merge: remote keys + compile-time keys, deduplicated.
      final compileKeys = _buildDefaultKeys();
      final mergedKeys = <String>{
        ..._youtubeApiKeys,
        ...compileKeys,
      }.where((k) => k.isNotEmpty).toList();
      if (mergedKeys.isNotEmpty) _youtubeApiKeys = mergedKeys;

      debugPrint(
        'RemoteConfigService: loaded ${_youtubeApiKeys.length} API keys, '
        '${_pipedInstances.length} Piped instances',
      );
    } catch (e) {
      // Silently fall back to compile-time defaults.
      debugPrint('RemoteConfigService: fallback to compile-time defaults ($e)');
    }

    _loaded = true;
  }

  // -- Helpers ---------------------------------------------------------------

  /// Parse compile-time YouTube API keys (singular + comma-separated).
  static List<String> _buildDefaultKeys() {
    final keys = <String>{};
    if (SupabaseConfig.youtubeApiKey.isNotEmpty) {
      keys.add(SupabaseConfig.youtubeApiKey);
    }
    if (SupabaseConfig.youtubeApiKeys.isNotEmpty) {
      keys.addAll(
        SupabaseConfig.youtubeApiKeys
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty),
      );
    }
    return keys.toList();
  }

  /// Parse compile-time Piped instance list.
  static List<String> _buildDefaultPipedInstances() {
    if (SupabaseConfig.pipedInstances.isEmpty) {
      return ['https://pipedapi.kavin.rocks', 'https://pipedapi.adminforge.de'];
    }
    return SupabaseConfig.pipedInstances
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Extract a `List<String>` from a JSONB value (which Supabase returns
  /// as a Dart `List<dynamic>`).
  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}
