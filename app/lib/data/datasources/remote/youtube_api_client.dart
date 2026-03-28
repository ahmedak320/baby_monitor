import 'package:dio/dio.dart';

import '../../../config/supabase_config.dart';
import '../../models/video_metadata.dart';
import '../local/preferences_cache.dart';
import 'circuit_breaker.dart';
import 'remote_config_service.dart';

/// Exception thrown when YouTube API quota is exhausted.
class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException([this.message = 'YouTube API quota exceeded']);
  @override
  String toString() => message;
}

/// Pure YouTube Data API v3 client with multi-key rotation.
///
/// This client no longer contains Piped fallback logic — that responsibility
/// moves to [YouTubeDataService] which orchestrates the full tier chain.
class YouTubeApiClient {
  final Dio _dio;
  final List<String> _apiKeys;
  final CircuitBreaker _circuitBreaker;

  static const _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static const _dailyQuotaLimit = 10000;

  int _currentKeyIndex = 0;

  YouTubeApiClient({
    Dio? dio,
    List<String>? apiKeys,
    CircuitBreaker? circuitBreaker,
  })  : _dio = dio ?? Dio(),
        _apiKeys = _buildKeyList(apiKeys),
        _circuitBreaker = circuitBreaker ??
            CircuitBreaker(failureThreshold: 3, cooldownDuration: const Duration(minutes: 15));

  /// Build a deduplicated, non-empty key list from explicit keys, remote config,
  /// and compile-time fallback.
  static List<String> _buildKeyList(List<String>? explicit) {
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.where((k) => k.isNotEmpty).toList();
    }
    // Try remote config first, then compile-time fallback.
    final remote = RemoteConfigService.instance.youtubeApiKeys;
    if (remote.isNotEmpty) return remote;
    if (SupabaseConfig.youtubeApiKey.isNotEmpty) {
      return [SupabaseConfig.youtubeApiKey];
    }
    return [];
  }

  /// Whether any API key has remaining quota.
  bool get hasQuota => _getAvailableKey() != null;

  /// Total remaining quota across all keys.
  int get remainingQuota {
    _checkDailyReset();
    var total = 0;
    for (var i = 0; i < _apiKeys.length; i++) {
      final hash = _keyHash(i);
      final used = PreferencesCache.getYtKeyUsage(hash);
      total += (_dailyQuotaLimit - used).clamp(0, _dailyQuotaLimit);
    }
    return total;
  }

  // ==========================================
  // PUBLIC API (YouTube Data API v3 only)
  // ==========================================

  /// Search for videos. Throws [QuotaExceededException] if all keys exhausted.
  Future<VideoSearchResult> search(
    String query, {
    int maxResults = 20,
    String? pageToken,
  }) async {
    return _withKeyRotation(100, (key) => _officialSearch(query,
        maxResults: maxResults, pageToken: pageToken, apiKey: key));
  }

  /// Get video details.
  Future<VideoMetadata> getVideoDetails(String videoId) async {
    return _withKeyRotation(1, (key) => _officialGetVideo(videoId, apiKey: key));
  }

  /// Get multiple video details in a batch.
  Future<List<VideoMetadata>> getVideoDetailsBatch(List<String> videoIds) async {
    return _withKeyRotation(1, (key) => _officialGetVideoBatch(videoIds, apiKey: key));
  }

  /// Get channel info.
  Future<ChannelMetadata> getChannelInfo(String channelId) async {
    return _withKeyRotation(1, (key) => _officialGetChannel(channelId, apiKey: key));
  }

  /// Get recent uploads from a channel.
  Future<List<VideoMetadata>> getChannelVideos(String channelId) async {
    return _withKeyRotation(2, (key) => _officialGetChannelUploads(channelId, apiKey: key));
  }

  /// Get trending videos.
  Future<List<VideoMetadata>> getTrending({String region = 'US'}) async {
    return _withKeyRotation(1, (key) => _officialGetTrending(region: region, apiKey: key));
  }

  /// Get related videos via search (expensive — 100 units).
  Future<List<VideoMetadata>> getRelatedVideos(String videoId) async {
    return _withKeyRotation(100, (key) => _officialRelatedVideos(videoId, apiKey: key));
  }

  // ==========================================
  // KEY ROTATION + CIRCUIT BREAKER
  // ==========================================

  /// Execute [action] with key rotation and circuit breaker.
  ///
  /// If the current key gets a 403, marks it exhausted and retries with the
  /// next available key (once). If all keys are exhausted or the circuit is
  /// open, throws [QuotaExceededException].
  Future<T> _withKeyRotation<T>(int cost, Future<T> Function(String key) action) async {
    if (_circuitBreaker.isOpen) {
      throw const QuotaExceededException('YouTube API circuit breaker open');
    }

    final key = _getAvailableKey();
    if (key == null) {
      throw const QuotaExceededException('All YouTube API keys exhausted');
    }

    try {
      final result = await action(key);
      _circuitBreaker.recordSuccess();
      await _recordKeyUsage(_currentKeyIndex, cost);
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Mark current key exhausted and try next.
        await _recordKeyUsage(_currentKeyIndex, _dailyQuotaLimit);
        _circuitBreaker.recordFailure();

        final nextKey = _getAvailableKey();
        if (nextKey != null) {
          try {
            final result = await action(nextKey);
            _circuitBreaker.recordSuccess();
            await _recordKeyUsage(_currentKeyIndex, cost);
            return result;
          } on DioException catch (e2) {
            _circuitBreaker.recordFailure();
            if (e2.response?.statusCode == 403) {
              await _recordKeyUsage(_currentKeyIndex, _dailyQuotaLimit);
              throw const QuotaExceededException();
            }
            rethrow;
          }
        }
        throw const QuotaExceededException();
      }
      _circuitBreaker.recordFailure();
      rethrow;
    }
  }

  /// Get the next API key with remaining quota, or null if all exhausted.
  String? _getAvailableKey() {
    _checkDailyReset();
    if (_apiKeys.isEmpty) return null;

    // Start from current index and cycle through all keys.
    for (var i = 0; i < _apiKeys.length; i++) {
      final idx = (_currentKeyIndex + i) % _apiKeys.length;
      final hash = _keyHash(idx);
      final used = PreferencesCache.getYtKeyUsage(hash);
      if (used < _dailyQuotaLimit) {
        _currentKeyIndex = idx;
        return _apiKeys[idx];
      }
    }
    return null;
  }

  /// Record quota usage for a key.
  Future<void> _recordKeyUsage(int keyIndex, int cost) async {
    final hash = _keyHash(keyIndex);
    final current = PreferencesCache.getYtKeyUsage(hash);
    await PreferencesCache.setYtKeyUsage(hash, current + cost);
  }

  /// Check if it's a new day and reset all key quotas.
  /// Hive writes are synchronous in-memory; the returned Future is for
  /// disk persistence only, so fire-and-forget is acceptable here.
  void _checkDailyReset() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastReset = PreferencesCache.getYtKeyResetDate();
    if (lastReset != today) {
      // Reset all key usage counters (Hive in-memory is sync).
      for (var i = 0; i < _apiKeys.length; i++) {
        // ignore: discarded_futures
        PreferencesCache.setYtKeyUsage(_keyHash(i), 0);
      }
      // ignore: discarded_futures
      PreferencesCache.setYtKeyResetDate(today);
      _currentKeyIndex = 0;
    }
  }

  /// Hash of key content for Hive storage (avoids storing raw API keys,
  /// stable across key reordering).
  String _keyHash(int index) =>
      'k${_apiKeys[index].hashCode.toRadixString(16)}';

  // ==========================================
  // OFFICIAL YOUTUBE DATA API v3
  // ==========================================

  Future<List<VideoMetadata>> _officialGetTrending({
    String region = 'US',
    required String apiKey,
  }) async {
    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'chart': 'mostPopular',
      'regionCode': region,
      'videoCategoryId': '24',
      'maxResults': 20,
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items
        .map((item) => _parseOfficialVideoItem(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VideoMetadata>> _officialRelatedVideos(
    String videoId, {
    required String apiKey,
  }) async {
    final response = await _dio.get('$_baseUrl/search', queryParameters: {
      'part': 'snippet',
      'relatedToVideoId': videoId,
      'type': 'video',
      'safeSearch': 'strict',
      'maxResults': 10,
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final id = item['id'] as Map<String, dynamic>;
      return VideoMetadata(
        videoId: id['videoId'] as String? ?? '',
        title: snippet['title'] as String? ?? '',
        description: snippet['description'] as String? ?? '',
        channelId: snippet['channelId'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      );
    }).toList();
  }

  Future<VideoSearchResult> _officialSearch(
    String query, {
    int maxResults = 20,
    String? pageToken,
    required String apiKey,
  }) async {
    final params = <String, dynamic>{
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': maxResults,
      'safeSearch': 'strict',
      'key': apiKey,
    };
    if (pageToken != null) params['pageToken'] = pageToken;

    final response =
        await _dio.get('$_baseUrl/search', queryParameters: params);

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    final videos = items.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final id = item['id'] as Map<String, dynamic>;
      return VideoMetadata(
        videoId: id['videoId'] as String? ?? '',
        title: snippet['title'] as String? ?? '',
        description: snippet['description'] as String? ?? '',
        channelId: snippet['channelId'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      );
    }).toList();

    return VideoSearchResult(
      videos: videos,
      nextPageToken: data['nextPageToken'] as String?,
    );
  }

  Future<VideoMetadata> _officialGetVideo(
    String videoId, {
    required String apiKey,
  }) async {
    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'id': videoId,
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    if (items.isEmpty) {
      throw Exception('Video not found: $videoId');
    }

    return _parseOfficialVideoItem(items.first as Map<String, dynamic>);
  }

  Future<List<VideoMetadata>> _officialGetVideoBatch(
    List<String> videoIds, {
    required String apiKey,
  }) async {
    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'id': videoIds.join(','),
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items
        .map((item) => _parseOfficialVideoItem(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChannelMetadata> _officialGetChannel(
    String channelId, {
    required String apiKey,
  }) async {
    final response = await _dio.get('$_baseUrl/channels', queryParameters: {
      'part': 'snippet,statistics',
      'id': channelId,
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    if (items.isEmpty) {
      throw Exception('Channel not found: $channelId');
    }

    final item = items.first as Map<String, dynamic>;
    final snippet = item['snippet'] as Map<String, dynamic>;
    final stats = item['statistics'] as Map<String, dynamic>? ?? {};

    return ChannelMetadata(
      channelId: channelId,
      title: snippet['title'] as String? ?? '',
      description: snippet['description'] as String? ?? '',
      thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
      subscriberCount:
          int.tryParse(stats['subscriberCount'] as String? ?? '0') ?? 0,
    );
  }

  Future<List<VideoMetadata>> _officialGetChannelUploads(
    String channelId, {
    required String apiKey,
  }) async {
    final channelResponse =
        await _dio.get('$_baseUrl/channels', queryParameters: {
      'part': 'contentDetails',
      'id': channelId,
      'key': apiKey,
    });

    final channelItems = (channelResponse.data['items'] as List?) ?? [];
    if (channelItems.isEmpty) return [];

    final contentDetails =
        channelItems.first['contentDetails'] as Map<String, dynamic>;
    final uploadsPlaylistId =
        (contentDetails['relatedPlaylists']
            as Map<String, dynamic>)['uploads'] as String?;

    if (uploadsPlaylistId == null) return [];

    final response =
        await _dio.get('$_baseUrl/playlistItems', queryParameters: {
      'part': 'snippet',
      'playlistId': uploadsPlaylistId,
      'maxResults': 50,
      'key': apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final resourceId = snippet['resourceId'] as Map<String, dynamic>;
      return VideoMetadata(
        videoId: resourceId['videoId'] as String? ?? '',
        title: snippet['title'] as String? ?? '',
        description: snippet['description'] as String? ?? '',
        channelId: snippet['channelId'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      );
    }).toList();
  }

  // ==========================================
  // HELPERS
  // ==========================================

  VideoMetadata _parseOfficialVideoItem(Map<String, dynamic> item) {
    final snippet = item['snippet'] as Map<String, dynamic>;
    final contentDetails =
        item['contentDetails'] as Map<String, dynamic>? ?? {};
    final stats = item['statistics'] as Map<String, dynamic>? ?? {};

    return VideoMetadata(
      videoId: item['id'] as String? ?? '',
      title: snippet['title'] as String? ?? '',
      description: snippet['description'] as String? ?? '',
      channelId: snippet['channelId'] as String? ?? '',
      channelTitle: snippet['channelTitle'] as String? ?? '',
      thumbnailUrl: _bestThumbnail(snippet['thumbnails']),
      durationSeconds:
          _parseDuration(contentDetails['duration'] as String? ?? ''),
      publishedAt:
          DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      tags: (snippet['tags'] as List?)?.cast<String>() ?? [],
      categoryId:
          int.tryParse(snippet['categoryId'] as String? ?? '0') ?? 0,
      hasCaptions: contentDetails['caption'] == 'true',
      viewCount:
          int.tryParse(stats['viewCount'] as String? ?? '0') ?? 0,
      likeCount:
          int.tryParse(stats['likeCount'] as String? ?? '0') ?? 0,
    );
  }

  /// Parse ISO 8601 duration (PT1H2M3S) to seconds.
  int _parseDuration(String iso) {
    final match =
        RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (match == null) return 0;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  /// Get best available thumbnail URL.
  String _bestThumbnail(dynamic thumbnails) {
    if (thumbnails == null) return '';
    final map = thumbnails as Map<String, dynamic>;
    for (final key in ['maxres', 'high', 'medium', 'default']) {
      if (map.containsKey(key)) {
        return (map[key] as Map<String, dynamic>)['url'] as String? ?? '';
      }
    }
    return '';
  }
}
