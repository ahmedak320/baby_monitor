import 'package:dio/dio.dart';

import '../../models/video_metadata.dart';

/// Client for the Piped API (open-source YouTube frontend).
/// Used as fallback when official YouTube API quota is exhausted.
class PipedApiClient {
  final Dio _dio;
  final String _baseUrl;

  PipedApiClient({String baseUrl = 'https://pipedapi.kavin.rocks', Dio? dio})
    : _baseUrl = baseUrl,
      _dio = dio ?? Dio();

  /// Search for videos.
  Future<VideoSearchResult> search(String query, {String? filter}) async {
    final response = await _dio.get(
      '$_baseUrl/search',
      queryParameters: {'q': query, 'filter': filter ?? 'videos'},
    );

    final data = response.data;
    final items = (data['items'] as List?) ?? [];

    final videos = items
        .where((item) => item['type'] == 'stream')
        .map((item) => _parseStreamItem(item as Map<String, dynamic>))
        .toList();

    return VideoSearchResult(
      videos: videos,
      nextPageToken: data['nextpage'] as String?,
    );
  }

  /// Get video details by ID.
  Future<VideoMetadata> getVideoDetails(String videoId) async {
    final response = await _dio.get('$_baseUrl/streams/$videoId');
    final data = response.data as Map<String, dynamic>;

    return VideoMetadata(
      videoId: videoId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      channelId: _extractChannelId(data['uploaderUrl'] as String? ?? ''),
      channelTitle: data['uploader'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      durationSeconds: data['duration'] as int? ?? 0,
      publishedAt: data['uploadDate'] != null
          ? DateTime.tryParse(data['uploadDate'] as String)
          : null,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      viewCount: data['views'] as int? ?? 0,
      likeCount: data['likes'] as int? ?? 0,
    );
  }

  /// Search for channels by name.
  Future<List<ChannelMetadata>> searchChannels(String query) async {
    final response = await _dio.get(
      '$_baseUrl/search',
      queryParameters: {'q': query, 'filter': 'channels'},
    );

    final data = response.data;
    final items = (data['items'] as List?) ?? [];

    return items
        .where((item) => item['type'] == 'channel')
        .map((item) => _parseChannelItem(item as Map<String, dynamic>))
        .toList();
  }

  /// Get channel info.
  Future<ChannelMetadata> getChannelInfo(String channelId) async {
    final response = await _dio.get('$_baseUrl/channel/$channelId');
    final data = response.data as Map<String, dynamic>;

    return ChannelMetadata(
      channelId: channelId,
      title: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      thumbnailUrl: data['avatarUrl'] as String? ?? '',
      subscriberCount: data['subscriberCount'] as int? ?? 0,
    );
  }

  /// Get channel videos (recent uploads).
  Future<List<VideoMetadata>> getChannelVideos(String channelId) async {
    final response = await _dio.get('$_baseUrl/channel/$channelId');
    final data = response.data as Map<String, dynamic>;
    final items = (data['relatedStreams'] as List?) ?? [];

    return items
        .map((item) => _parseStreamItem(item as Map<String, dynamic>))
        .toList();
  }

  /// Get trending videos.
  Future<List<VideoMetadata>> getTrending({String region = 'US'}) async {
    final response = await _dio.get(
      '$_baseUrl/trending',
      queryParameters: {'region': region},
    );

    final items = (response.data as List?) ?? [];
    return items
        .map((item) => _parseStreamItem(item as Map<String, dynamic>))
        .toList();
  }

  /// Get related videos for a given video.
  Future<List<VideoMetadata>> getRelatedVideos(String videoId) async {
    final response = await _dio.get('$_baseUrl/streams/$videoId');
    final data = response.data as Map<String, dynamic>;
    final items = (data['relatedStreams'] as List?) ?? [];

    return items
        .where((item) => item['type'] == 'stream')
        .map((item) => _parseStreamItem(item as Map<String, dynamic>))
        .toList();
  }

  VideoMetadata _parseStreamItem(Map<String, dynamic> item) {
    final url = item['url'] as String? ?? '';
    final videoId = _extractVideoId(url);

    return VideoMetadata(
      videoId: videoId,
      title: item['title'] as String? ?? '',
      description: item['shortDescription'] as String? ?? '',
      channelId: _extractChannelId(item['uploaderUrl'] as String? ?? ''),
      channelTitle: item['uploaderName'] as String? ?? '',
      thumbnailUrl: item['thumbnail'] as String? ?? '',
      durationSeconds: item['duration'] as int? ?? 0,
      publishedAt: item['uploadedDate'] != null
          ? _parseRelativeDate(item['uploadedDate'] as String)
          : (item['uploaded'] != null
                ? DateTime.fromMillisecondsSinceEpoch(item['uploaded'] as int)
                : null),
      viewCount: item['views'] as int? ?? 0,
    );
  }

  String _extractVideoId(String url) {
    // /watch?v=VIDEO_ID
    final match = RegExp(r'[?&]v=([^&]+)').firstMatch(url);
    return match?.group(1) ?? url.split('/').last;
  }

  String _extractChannelId(String url) {
    // /channel/CHANNEL_ID
    return url.split('/').last;
  }

  ChannelMetadata _parseChannelItem(Map<String, dynamic> item) {
    final url = item['url'] as String? ?? '';
    final channelId = _extractChannelId(url);

    return ChannelMetadata(
      channelId: channelId,
      title: item['name'] as String? ?? '',
      description: item['description'] as String? ?? '',
      thumbnailUrl: item['thumbnail'] as String? ?? '',
      subscriberCount: item['subscribers'] as int? ?? 0,
    );
  }

  DateTime? _parseRelativeDate(String relative) {
    // "2 days ago", "3 months ago", etc. — approximate
    final now = DateTime.now();
    final parts = relative.split(' ');
    if (parts.length < 2) return null;
    final amount = int.tryParse(parts[0]) ?? 0;
    final unit = parts[1].toLowerCase();
    if (unit.startsWith('second'))
      return now.subtract(Duration(seconds: amount));
    if (unit.startsWith('minute'))
      return now.subtract(Duration(minutes: amount));
    if (unit.startsWith('hour')) return now.subtract(Duration(hours: amount));
    if (unit.startsWith('day')) return now.subtract(Duration(days: amount));
    if (unit.startsWith('week'))
      return now.subtract(Duration(days: amount * 7));
    if (unit.startsWith('month'))
      return now.subtract(Duration(days: amount * 30));
    if (unit.startsWith('year'))
      return now.subtract(Duration(days: amount * 365));
    return null;
  }
}
