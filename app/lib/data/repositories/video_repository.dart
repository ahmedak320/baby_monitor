import '../datasources/local/approved_cache.dart';
import '../datasources/remote/supabase_client.dart';
import '../datasources/remote/youtube_api_client.dart';
import '../models/video_metadata.dart';

/// Analysis result for a video.
class VideoAnalysis {
  final String videoId;
  final int ageMinAppropriate;
  final int ageMaxAppropriate;
  final double overstimulationScore;
  final double educationalScore;
  final double scarinessScore;
  final double brainrotScore;
  final double languageSafetyScore;
  final double violenceScore;
  final double audioSafetyScore;
  final List<String> contentLabels;
  final List<String> detectedIssues;
  final double confidence;
  final bool isGloballyBlacklisted;

  const VideoAnalysis({
    required this.videoId,
    this.ageMinAppropriate = 0,
    this.ageMaxAppropriate = 18,
    this.overstimulationScore = 0,
    this.educationalScore = 0,
    this.scarinessScore = 0,
    this.brainrotScore = 0,
    this.languageSafetyScore = 10,
    this.violenceScore = 0,
    this.audioSafetyScore = 10,
    this.contentLabels = const [],
    this.detectedIssues = const [],
    this.confidence = 0,
    this.isGloballyBlacklisted = false,
  });

  factory VideoAnalysis.fromJson(Map<String, dynamic> json) {
    return VideoAnalysis(
      videoId: json['video_id'] as String,
      ageMinAppropriate: json['age_min_appropriate'] as int? ?? 0,
      ageMaxAppropriate: json['age_max_appropriate'] as int? ?? 18,
      overstimulationScore:
          (json['overstimulation_score'] as num?)?.toDouble() ?? 0,
      educationalScore: (json['educational_score'] as num?)?.toDouble() ?? 0,
      scarinessScore: (json['scariness_score'] as num?)?.toDouble() ?? 0,
      brainrotScore: (json['brainrot_score'] as num?)?.toDouble() ?? 0,
      languageSafetyScore:
          (json['language_safety_score'] as num?)?.toDouble() ?? 10,
      violenceScore: (json['violence_score'] as num?)?.toDouble() ?? 0,
      audioSafetyScore:
          (json['audio_safety_score'] as num?)?.toDouble() ?? 10,
      contentLabels:
          (json['content_labels'] as List?)?.cast<String>() ?? [],
      detectedIssues:
          (json['detected_issues'] as List?)?.cast<String>() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      isGloballyBlacklisted:
          json['is_globally_blacklisted'] as bool? ?? false,
    );
  }
}

/// Repository managing the full video lifecycle:
/// fetch from YouTube, persist to Supabase, cache locally, queue for analysis.
class VideoRepository {
  final _client = SupabaseClientWrapper.client;
  final YouTubeApiClient _youtubeApi;

  VideoRepository({YouTubeApiClient? youtubeApi})
      : _youtubeApi = youtubeApi ?? YouTubeApiClient();

  // ==========================================
  // VIDEO METADATA
  // ==========================================

  /// Fetch video from Supabase cache, or from YouTube API if not cached.
  Future<VideoMetadata?> getVideo(String videoId) async {
    // Check Supabase first
    final row = await _client
        .from('yt_videos')
        .select()
        .eq('video_id', videoId)
        .maybeSingle();

    if (row != null) return VideoMetadata.fromSupabaseRow(row);

    // Fetch from YouTube and cache
    try {
      final video = await _youtubeApi.getVideoDetails(videoId);
      await _upsertVideo(video);
      return video;
    } catch (_) {
      return null;
    }
  }

  /// Search videos, caching results in Supabase.
  Future<List<VideoMetadata>> searchVideos(String query) async {
    final result = await _youtubeApi.search(query);
    // Cache results in background
    for (final video in result.videos) {
      _upsertVideo(video); // fire and forget
    }
    return result.videos;
  }

  /// Get approved videos for a child profile.
  Future<List<VideoMetadata>> getApprovedVideos({
    required String childId,
    required int childAge,
    int limit = 50,
  }) async {
    // Check local cache first for offline support
    final cachedIds = ApprovedCache.getApprovedVideoIds(childId);
    if (cachedIds.isNotEmpty) {
      final rows = await _client
          .from('yt_videos')
          .select()
          .inFilter('video_id', cachedIds.take(limit).toList())
          .limit(limit);

      return (rows as List)
          .map((r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>))
          .toList();
    }

    // Query videos with completed analyses suitable for this age
    final rows = await _client
        .from('yt_videos')
        .select('*, video_analyses!inner(*)')
        .eq('analysis_status', 'completed')
        .lte('video_analyses.age_min_appropriate', childAge)
        .gte('video_analyses.age_max_appropriate', childAge)
        .eq('video_analyses.is_globally_blacklisted', false)
        .limit(limit);

    final videos = (rows as List)
        .map((r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>))
        .toList();

    // Update local cache
    final videoIds = videos.map((v) => v.videoId).toList();
    await ApprovedCache.setApprovedVideoIds(childId, videoIds);

    return videos;
  }

  /// Get channel uploads and cache them.
  Future<List<VideoMetadata>> getChannelUploads(String channelId) async {
    final videos = await _youtubeApi.getChannelVideos(channelId);
    for (final video in videos) {
      _upsertVideo(video);
    }
    return videos;
  }

  // ==========================================
  // ANALYSIS
  // ==========================================

  /// Get the community analysis for a video.
  Future<VideoAnalysis?> getAnalysis(String videoId) async {
    final row = await _client
        .from('video_analyses')
        .select()
        .eq('video_id', videoId)
        .maybeSingle();

    if (row == null) return null;
    return VideoAnalysis.fromJson(row);
  }

  /// Request analysis for a video (add to queue).
  Future<void> requestAnalysis(
    String videoId, {
    int priority = 5,
    String source = 'manual',
  }) async {
    final userId = SupabaseClientWrapper.currentUserId;

    // Check if already queued or completed
    final existing = await _client
        .from('analysis_queue')
        .select('id')
        .eq('video_id', videoId)
        .inFilter('status', ['queued', 'processing'])
        .maybeSingle();

    if (existing != null) return; // Already in queue

    await _client.from('analysis_queue').insert({
      'video_id': videoId,
      'requested_by': userId,
      'priority': priority,
      'source': source,
    });
  }

  /// Upsert a video into the database with discovery metadata.
  Future<void> upsertVideo(
    VideoMetadata video, {
    String source = 'manual',
    String analysisStatus = 'pending',
    bool metadataGatePassed = false,
    String? metadataGateReason,
  }) async {
    final row = video.toSupabaseRow(source: source);
    row['analysis_status'] = analysisStatus;
    row['metadata_gate_passed'] = metadataGatePassed;
    if (metadataGateReason != null) {
      row['metadata_gate_reason'] = metadataGateReason;
    }

    // Upsert channel if we have channel info
    if (video.channelId.isNotEmpty) {
      await _client.from('yt_channels').upsert({
        'channel_id': video.channelId,
        'title': video.channelTitle,
      }, onConflict: 'channel_id');
    }

    await _client.from('yt_videos').upsert(
      row,
      onConflict: 'video_id',
    );
  }

  /// Log a video interruption (when analysis rejects mid-play).
  Future<void> logInterruption({
    required String childId,
    required String videoId,
    required String reason,
    required int watchedSeconds,
  }) async {
    await _client.from('video_interruptions').insert({
      'child_id': childId,
      'video_id': videoId,
      'reason': reason,
      'watch_seconds_before_interrupt': watchedSeconds,
    });
  }

  // ==========================================
  // WATCH HISTORY
  // ==========================================

  /// Record that a child watched a video.
  Future<void> recordWatch({
    required String childId,
    required String videoId,
    required int durationSeconds,
    required bool completed,
  }) async {
    await _client.from('watch_history').insert({
      'child_id': childId,
      'video_id': videoId,
      'watch_duration_seconds': durationSeconds,
      'completed': completed,
    });
  }

  /// Get watch history for a child.
  Future<List<Map<String, dynamic>>> getWatchHistory(
    String childId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('watch_history')
        .select('*, yt_videos(*)')
        .eq('child_id', childId)
        .order('watched_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ==========================================
  // FILTERED LOG
  // ==========================================

  /// Get filtered video log for a child.
  Future<List<Map<String, dynamic>>> getFilteredLog(
    String childId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('filtered_log')
        .select('*, yt_videos(*)')
        .eq('child_id', childId)
        .order('filtered_at', ascending: false)
        .limit(limit);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  Future<void> _upsertVideo(VideoMetadata video) async {
    if (video.videoId.isEmpty) return;

    // Upsert channel first if we have channel data
    if (video.channelId.isNotEmpty) {
      await _client.from('yt_channels').upsert(
        {
          'channel_id': video.channelId,
          'title': video.channelTitle.isNotEmpty
              ? video.channelTitle
              : 'Unknown Channel',
        },
        onConflict: 'channel_id',
      );
    }

    await _client.from('yt_videos').upsert(
      video.toSupabaseRow(),
      onConflict: 'video_id',
    );
  }
}
