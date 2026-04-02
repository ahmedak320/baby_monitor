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
  final bool? isEmbeddable;
  final String? privacyStatus;
  final bool? madeForKids;
  final DateTime? lastPlayabilityCheckAt;
  final double? metadataGateConfidence;
  final DateTime? metadataCheckedAt;
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
    this.isEmbeddable,
    this.privacyStatus,
    this.madeForKids,
    this.lastPlayabilityCheckAt,
    this.metadataGateConfidence,
    this.metadataCheckedAt,
    this.analysisStatus,
    this.discoverySource,
    this.lastFetchedAt,
  });

  /// Detect if this video is a YouTube Short.
  bool get detectedAsShort =>
      isShort ||
      durationSeconds > 0 && durationSeconds <= 60 ||
      title.toLowerCase().contains('#shorts');

  Map<String, dynamic> toSupabaseRow({String? source}) {
    final data = <String, dynamic>{
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
      'is_embeddable': isEmbeddable,
      'privacy_status': privacyStatus,
      'made_for_kids': madeForKids,
      'last_playability_check_at': lastPlayabilityCheckAt?.toIso8601String(),
      'metadata_gate_confidence': metadataGateConfidence,
      'metadata_checked_at': metadataCheckedAt?.toIso8601String(),
      'last_fetched_at': DateTime.now().toIso8601String(),
    };
    if (source != null) {
      data['discovery_source'] = source;
    }
    return data;
  }

  factory VideoMetadata.fromSupabaseRow(Map<String, dynamic> row) {
    final joinedChannel = row['yt_channels'];
    String channelTitle = '';
    if (joinedChannel is Map<String, dynamic>) {
      channelTitle = joinedChannel['title'] as String? ?? '';
    } else if (joinedChannel is List && joinedChannel.isNotEmpty) {
      final first = joinedChannel.first;
      if (first is Map<String, dynamic>) {
        channelTitle = first['title'] as String? ?? '';
      }
    }

    return VideoMetadata(
      videoId: row['video_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      channelId: row['channel_id'] as String? ?? '',
      channelTitle: channelTitle,
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
      isEmbeddable: row['is_embeddable'] as bool?,
      privacyStatus: row['privacy_status'] as String?,
      madeForKids: row['made_for_kids'] as bool?,
      lastPlayabilityCheckAt: row['last_playability_check_at'] != null
          ? DateTime.tryParse(row['last_playability_check_at'] as String)
          : null,
      metadataGateConfidence: (row['metadata_gate_confidence'] as num?)
          ?.toDouble(),
      metadataCheckedAt: row['metadata_checked_at'] != null
          ? DateTime.tryParse(row['metadata_checked_at'] as String)
          : null,
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

  const VideoSearchResult({required this.videos, this.nextPageToken});
}
