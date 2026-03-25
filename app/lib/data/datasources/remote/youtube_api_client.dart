import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/video_metadata.dart';
import 'piped_api_client.dart';

/// Exception thrown when YouTube API quota is exhausted.
class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException([this.message = 'YouTube API quota exceeded']);
  @override
  String toString() => message;
}

/// Hybrid YouTube API client.
/// Uses official YouTube Data API v3 as primary, falls back to Piped API
/// when quota is exhausted.
class YouTubeApiClient {
  final Dio _dio;
  final PipedApiClient _piped;
  final String _apiKey;

  static const _baseUrl = 'https://www.googleapis.com/youtube/v3';

  // Track daily quota usage
  int _quotaUsed = 0;
  DateTime _quotaResetDate = DateTime.now();
  static const _dailyQuotaLimit = 10000;

  YouTubeApiClient({
    Dio? dio,
    PipedApiClient? piped,
    String? apiKey,
  })  : _dio = dio ?? Dio(),
        _piped = piped ?? PipedApiClient(),
        _apiKey = apiKey ?? dotenv.env['YOUTUBE_API_KEY'] ?? '';

  /// Whether the official API has quota remaining.
  bool get _hasQuota {
    _resetQuotaIfNewDay();
    return _quotaUsed < _dailyQuotaLimit;
  }

  void _resetQuotaIfNewDay() {
    final now = DateTime.now();
    if (now.day != _quotaResetDate.day ||
        now.month != _quotaResetDate.month ||
        now.year != _quotaResetDate.year) {
      _quotaUsed = 0;
      _quotaResetDate = now;
    }
  }

  void _useQuota(int cost) {
    _quotaUsed += cost;
  }

  // ==========================================
  // PUBLIC API (auto-fallback)
  // ==========================================

  /// Search for videos. Falls back to Piped if quota exceeded.
  Future<VideoSearchResult> search(
    String query, {
    int maxResults = 20,
    String? pageToken,
  }) async {
    if (_hasQuota && _apiKey.isNotEmpty) {
      try {
        return await _officialSearch(query,
            maxResults: maxResults, pageToken: pageToken);
      } on QuotaExceededException {
        // Fall through to Piped
      }
    }
    return _piped.search(query);
  }

  /// Get video details. Falls back to Piped if quota exceeded.
  Future<VideoMetadata> getVideoDetails(String videoId) async {
    if (_hasQuota && _apiKey.isNotEmpty) {
      try {
        return await _officialGetVideo(videoId);
      } on QuotaExceededException {
        // Fall through to Piped
      }
    }
    return _piped.getVideoDetails(videoId);
  }

  /// Get multiple video details in a batch (comma-separated IDs).
  Future<List<VideoMetadata>> getVideoDetailsBatch(
      List<String> videoIds) async {
    if (_hasQuota && _apiKey.isNotEmpty) {
      try {
        return await _officialGetVideoBatch(videoIds);
      } on QuotaExceededException {
        // Fall through to Piped one-by-one
      }
    }
    final results = <VideoMetadata>[];
    for (final id in videoIds) {
      try {
        results.add(await _piped.getVideoDetails(id));
      } catch (_) {
        // Skip failed videos
      }
    }
    return results;
  }

  /// Get channel info.
  Future<ChannelMetadata> getChannelInfo(String channelId) async {
    if (_hasQuota && _apiKey.isNotEmpty) {
      try {
        return await _officialGetChannel(channelId);
      } on QuotaExceededException {
        // Fall through
      }
    }
    return _piped.getChannelInfo(channelId);
  }

  /// Get recent uploads from a channel.
  Future<List<VideoMetadata>> getChannelVideos(String channelId) async {
    if (_hasQuota && _apiKey.isNotEmpty) {
      try {
        return await _officialGetChannelUploads(channelId);
      } on QuotaExceededException {
        // Fall through
      }
    }
    return _piped.getChannelVideos(channelId);
  }

  /// Get trending videos. Uses Piped by default (free) or official API.
  Future<List<VideoMetadata>> getTrending({String region = 'US'}) async {
    // Prefer Piped for trending (free, no quota cost)
    try {
      return await _piped.getTrending(region: region);
    } catch (_) {
      // Fallback to official API
      if (!_hasQuota || _apiKey.isEmpty) return [];
      return _officialGetTrending(region: region);
    }
  }

  /// Get related/sidebar videos for a given video.
  /// Prefers Piped (free) over official API (100 units per search).
  Future<List<VideoMetadata>> getRelatedVideos(String videoId) async {
    try {
      return await _piped.getRelatedVideos(videoId);
    } catch (_) {
      // Piped failed — use official search with relatedToVideoId
      if (!_hasQuota || _apiKey.isEmpty) return [];
      return _officialRelatedVideos(videoId);
    }
  }

  // ==========================================
  // OFFICIAL YOUTUBE DATA API v3
  // ==========================================

  Future<List<VideoMetadata>> _officialGetTrending({
    String region = 'US',
  }) async {
    _useQuota(1); // videos.list with chart=mostPopular costs 1 unit

    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'chart': 'mostPopular',
      'regionCode': region,
      'videoCategoryId': '24', // Entertainment — includes kids content
      'maxResults': 20,
      'key': _apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items
        .map((item) =>
            _parseOfficialVideoItem(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VideoMetadata>> _officialRelatedVideos(String videoId) async {
    _useQuota(100); // search.list costs 100 units

    final response = await _dio.get('$_baseUrl/search', queryParameters: {
      'part': 'snippet',
      'relatedToVideoId': videoId,
      'type': 'video',
      'safeSearch': 'strict',
      'maxResults': 10,
      'key': _apiKey,
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
  }) async {
    _useQuota(100); // search.list costs 100 units

    final params = <String, dynamic>{
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': maxResults,
      'safeSearch': 'strict',
      'key': _apiKey,
    };
    if (pageToken != null) params['pageToken'] = pageToken;

    final response = await _dio.get('$_baseUrl/search', queryParameters: params);

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
        publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      );
    }).toList();

    return VideoSearchResult(
      videos: videos,
      nextPageToken: data['nextPageToken'] as String?,
    );
  }

  Future<VideoMetadata> _officialGetVideo(String videoId) async {
    _useQuota(1); // videos.list costs 1 unit

    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'id': videoId,
      'key': _apiKey,
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
      List<String> videoIds) async {
    _useQuota(1); // single videos.list call

    final response = await _dio.get('$_baseUrl/videos', queryParameters: {
      'part': 'snippet,contentDetails,statistics',
      'id': videoIds.join(','),
      'key': _apiKey,
    });

    if (response.statusCode == 403) {
      throw const QuotaExceededException();
    }

    final items = (response.data['items'] as List?) ?? [];
    return items
        .map((item) =>
            _parseOfficialVideoItem(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChannelMetadata> _officialGetChannel(String channelId) async {
    _useQuota(1); // channels.list costs 1 unit

    final response = await _dio.get('$_baseUrl/channels', queryParameters: {
      'part': 'snippet,statistics',
      'id': channelId,
      'key': _apiKey,
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
      String channelId) async {
    // First, get the uploads playlist ID
    _useQuota(1);
    final channelResponse =
        await _dio.get('$_baseUrl/channels', queryParameters: {
      'part': 'contentDetails',
      'id': channelId,
      'key': _apiKey,
    });

    final channelItems = (channelResponse.data['items'] as List?) ?? [];
    if (channelItems.isEmpty) return [];

    final contentDetails =
        channelItems.first['contentDetails'] as Map<String, dynamic>;
    final uploadsPlaylistId =
        (contentDetails['relatedPlaylists'] as Map<String, dynamic>)['uploads']
            as String?;

    if (uploadsPlaylistId == null) return [];

    // Then, get playlist items
    _useQuota(1); // playlistItems.list costs 1 unit
    final response =
        await _dio.get('$_baseUrl/playlistItems', queryParameters: {
      'part': 'snippet',
      'playlistId': uploadsPlaylistId,
      'maxResults': 50,
      'key': _apiKey,
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
      publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? ''),
      tags: (snippet['tags'] as List?)?.cast<String>() ?? [],
      categoryId:
          int.tryParse(snippet['categoryId'] as String? ?? '0') ?? 0,
      hasCaptions:
          contentDetails['caption'] == 'true',
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

  /// Remaining quota for the day.
  int get remainingQuota {
    _resetQuotaIfNewDay();
    return _dailyQuotaLimit - _quotaUsed;
  }
}
