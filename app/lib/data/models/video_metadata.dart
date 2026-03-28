/// Video metadata returned by YouTube or Piped API.
class VideoMetadata {
  final String videoId;
  final String title;
  final String description;
  final String channelId;
  final String channelTitle;
  final String thumbnailUrl;
  final int durationSeconds;
  final DateTime? publishedAt;
  final List<String> tags;
  final int categoryId;
  final bool hasCaptions;
  final int viewCount;
  final int likeCount;
  final bool isShort;
  final String? analysisStatus;
  final String? discoverySource;
  final DateTime? lastFetchedAt;

  const VideoMetadata({
    required this.videoId,
    required this.title,
    this.description = '',
    this.channelId = '',
    this.channelTitle = '',
    this.thumbnailUrl = '',
    this.durationSeconds = 0,
    this.publishedAt,
    this.tags = const [],
    this.categoryId = 0,
    this.hasCaptions = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isShort = false,
    this.analysisStatus,
    this.discoverySource,
    this.lastFetchedAt,
  });

  /// Detect if this video is a YouTube Short.
  bool get detectedAsShort =>
      isShort ||
      durationSeconds > 0 && durationSeconds <= 60 ||
      title.toLowerCase().contains('#shorts');

  Map<String, dynamic> toSupabaseRow({String? source}) => {
        'video_id': videoId,
        'channel_id': channelId.isNotEmpty ? channelId : null,
        'title': title,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'duration_seconds': durationSeconds,
        'published_at': publishedAt?.toIso8601String(),
        'tags': tags,
        'category_id': categoryId,
        'has_captions': hasCaptions,
        'view_count': viewCount,
        'like_count': likeCount,
        'is_short': detectedAsShort,
        if (source != null) 'discovery_source': source,
        'last_fetched_at': DateTime.now().toIso8601String(),
      };

  factory VideoMetadata.fromSupabaseRow(Map<String, dynamic> row) {
    return VideoMetadata(
      videoId: row['video_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      channelId: row['channel_id'] as String? ?? '',
      channelTitle: '', // not stored in yt_videos, joined from yt_channels
      thumbnailUrl: row['thumbnail_url'] as String? ?? '',
      durationSeconds: row['duration_seconds'] as int? ?? 0,
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'] as String)
          : null,
      tags: (row['tags'] as List?)?.cast<String>() ?? [],
      categoryId: row['category_id'] as int? ?? 0,
      hasCaptions: row['has_captions'] as bool? ?? false,
      viewCount: row['view_count'] as int? ?? 0,
      likeCount: row['like_count'] as int? ?? 0,
      isShort: row['is_short'] as bool? ?? false,
      analysisStatus: row['analysis_status'] as String?,
      discoverySource: row['discovery_source'] as String?,
      lastFetchedAt: row['last_fetched_at'] != null
          ? DateTime.tryParse(row['last_fetched_at'] as String)
          : null,
    );
  }
}

/// Channel metadata.
class ChannelMetadata {
  final String channelId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int subscriberCount;
  final bool isKidsChannel;
  final DateTime? lastFetchedAt;

  const ChannelMetadata({
    required this.channelId,
    required this.title,
    this.description = '',
    this.thumbnailUrl = '',
    this.subscriberCount = 0,
    this.isKidsChannel = false,
    this.lastFetchedAt,
  });

  Map<String, dynamic> toSupabaseRow() => {
        'channel_id': channelId,
        'title': title,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'subscriber_count': subscriberCount,
        'is_kids_channel': isKidsChannel,
        'last_fetched_at': DateTime.now().toIso8601String(),
      };

  factory ChannelMetadata.fromSupabaseRow(Map<String, dynamic> row) {
    return ChannelMetadata(
      channelId: row['channel_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      thumbnailUrl: row['thumbnail_url'] as String? ?? '',
      subscriberCount: (row['subscriber_count'] as int?) ?? 0,
      isKidsChannel: row['is_kids_channel'] as bool? ?? false,
      lastFetchedAt: row['last_fetched_at'] != null
          ? DateTime.tryParse(row['last_fetched_at'] as String)
          : null,
    );
  }
}

/// Search result container.
class VideoSearchResult {
  final List<VideoMetadata> videos;
  final String? nextPageToken;

  const VideoSearchResult({
    required this.videos,
    this.nextPageToken,
  });
}
