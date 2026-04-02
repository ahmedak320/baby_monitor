import 'package:flutter/foundation.dart' show debugPrint;

import '../datasources/local/approved_cache.dart';
import '../datasources/local/playability_cache.dart';
import '../datasources/remote/supabase_client.dart';
import '../../domain/services/youtube_data_service.dart';
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
  final String analysisReasoning;

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
    this.analysisReasoning = '',
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
      audioSafetyScore: (json['audio_safety_score'] as num?)?.toDouble() ?? 10,
      contentLabels: (json['content_labels'] as List?)?.cast<String>() ?? [],
      detectedIssues: (json['detected_issues'] as List?)?.cast<String>() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      isGloballyBlacklisted: json['is_globally_blacklisted'] as bool? ?? false,
      analysisReasoning: json['analysis_reasoning'] as String? ?? '',
    );
  }
}

/// Repository managing the full video lifecycle:
/// fetch from YouTube, persist to Supabase, cache locally, queue for analysis.
class VideoRepository {
  final _client = SupabaseClientWrapper.client;
  final YouTubeDataService _ytService;

  VideoRepository({YouTubeDataService? ytService})
    : _ytService = ytService ?? YouTubeDataService();

  // ==========================================
  // VIDEO METADATA
  // ==========================================

  /// Fetch video from Supabase cache, or from YouTube API if not cached.
  Future<VideoMetadata?> getVideo(String videoId) async {
    // Check Supabase first
    final row = await _client
        .from('yt_videos')
        .select('*, yt_channels(title)')
        .eq('video_id', videoId)
        .maybeSingle();

    if (row != null) return VideoMetadata.fromSupabaseRow(row);

    // Fetch via tiered resolution (YouTube API → Piped → stale cache)
    try {
      final video = await _ytService.getVideoDetails(videoId);
      await _upsertVideo(video);
      return video;
    } catch (_) {
      return null;
    }
  }

  /// Search videos, caching results in Supabase.
  Future<List<VideoMetadata>> searchVideos(String query) async {
    final result = await _ytService.search(query);
    // Cache results in background
    for (final video in result.videos) {
      _upsertVideo(video); // fire and forget
    }
    return result.videos;
  }

  /// Get approved videos for a child profile.
  /// If [includeMetadataApproved] is true, also returns videos that passed
  /// the metadata gate from trusted channels (analysis still pending).
  Future<List<VideoMetadata>> getApprovedVideos({
    required String childId,
    required int childAge,
    int limit = 50,
    bool includeMetadataApproved = false,
    bool includePending = false,
  }) async {
    await _syncPendingPlayabilityMarks();

    // Check local cache first for offline support
    final cachedIds = ApprovedCache.getApprovedVideoIds(childId);
    if (cachedIds.isNotEmpty && !includeMetadataApproved) {
      try {
        final rows = await _client
            .from('yt_videos')
            .select('*, yt_channels(title)')
            .inFilter('video_id', cachedIds.take(limit).toList())
            .limit(limit);

        return _filterPlayable(
          (rows as List)
              .map(
                (r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>),
              )
              .toList(),
        );
      } catch (e) {
        debugPrint('VideoRepository.getApprovedVideos cache fetch failed: $e');
      }
    }

    // Query fully analyzed + approved videos
    // age_min <= childAge: video is for this age or younger
    // age_max >= childAge - 4: include videos up to 4 years below
    //   (a 7-year-old can still enjoy content for ages 3+)
    final completedRows = await _client
        .from('yt_videos')
        .select('*, yt_channels(title), video_analyses!inner(*)')
        .eq('analysis_status', 'completed')
        .lte('video_analyses.age_min_appropriate', childAge)
        .gte('video_analyses.age_max_appropriate', (childAge - 4).clamp(0, 18))
        .eq('video_analyses.is_globally_blacklisted', false)
        .limit(limit);

    final videos = _filterPlayable(
      (completedRows as List)
          .map((r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>))
          .toList(),
    );

    // Optionally include metadata-approved videos from trusted channels
    if (includeMetadataApproved && videos.length < limit) {
      try {
        final remaining = limit - videos.length;
        final metadataRows = await _client
            .from('yt_videos')
            .select('*, yt_channels!inner(title)')
            .eq('analysis_status', 'metadata_approved')
            .eq('metadata_gate_passed', true)
            .gte('yt_channels.global_trust_score', 0.7)
            .limit(remaining);

        final metadataVideos = _filterPlayable(
          (metadataRows as List)
              .map(
                (r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>),
              )
              .toList(),
        );

        videos.addAll(metadataVideos);
      } catch (_) {
        // metadata_gate_passed column may not exist if migration not run
      }
    }

    // Optionally include pending/analyzing videos (show before analysis)
    if (includePending && videos.length < limit) {
      try {
        final remaining = limit - videos.length;
        final existingIds = videos.map((v) => v.videoId).toSet();
        final pendingRows = await _client
            .from('yt_videos')
            .select('*, yt_channels(title)')
            .inFilter('analysis_status', ['pending', 'analyzing'])
            .limit(remaining);

        final pendingVideos = _filterPlayable(
          (pendingRows as List)
              .map(
                (r) => VideoMetadata.fromSupabaseRow(r as Map<String, dynamic>),
              )
              .where((v) => !existingIds.contains(v.videoId))
              .toList(),
        );

        videos.addAll(pendingVideos);
      } catch (_) {
        // Graceful fallback if query fails
      }
    }

    // Only cache confirmed videos (not pending) for offline safety
    final confirmedIds = videos
        .where(
          (v) =>
              v.analysisStatus == 'completed' ||
              v.analysisStatus == 'metadata_approved',
        )
        .map((v) => v.videoId)
        .toList();
    await ApprovedCache.setApprovedVideoIds(childId, confirmedIds);

    return videos;
  }

  /// Get channel uploads and cache them.
  Future<List<VideoMetadata>> getChannelUploads(String channelId) async {
    final videos = await _ytService.getChannelVideos(channelId);
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
    try {
      final row = await _client
          .from('video_analyses')
          .select()
          .eq('video_id', videoId)
          .maybeSingle();

      if (row == null) return null;
      return VideoAnalysis.fromJson(row);
    } catch (e) {
      debugPrint('VideoRepository.getAnalysis failed for $videoId: $e');
      return null;
    }
  }

  Future<void> markVideoUnembeddable(String videoId) async {
    await PlayabilityCache.markBlocked(videoId, pendingRemoteSync: true);
    await _syncPlayabilityMark(videoId);
  }

  Future<void> _syncPendingPlayabilityMarks() async {
    final pendingIds = PlayabilityCache.getPendingSyncVideoIds();
    for (final videoId in pendingIds.take(10)) {
      await _syncPlayabilityMark(videoId);
    }
  }

  Future<void> _syncPlayabilityMark(String videoId) async {
    try {
      await _client
          .from('yt_videos')
          .update({
            'is_embeddable': false,
            'last_playability_check_at': DateTime.now().toIso8601String(),
          })
          .eq('video_id', videoId);
      await PlayabilityCache.clearPendingSyncVideoId(videoId);
    } catch (e) {
      debugPrint(
        'VideoRepository.markVideoUnembeddable failed for $videoId: $e',
      );
    }
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
    double? metadataGateConfidence,
    DateTime? metadataCheckedAt,
  }) async {
    await _ingestVideoCacheEntry(
      video,
      source: source,
      analysisStatus: analysisStatus,
      metadataGatePassed: metadataGatePassed,
      metadataGateReason: metadataGateReason,
      metadataGateConfidence: metadataGateConfidence,
      metadataCheckedAt: metadataCheckedAt,
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

  /// Log that a video was filtered/rejected for a child.
  Future<void> logFiltered({
    required String childId,
    required String videoId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'log_filtered_content',
        params: {
          'p_child_id': childId,
          'p_video_id': videoId,
          'p_reason': reason,
        },
      );
    } catch (_) {
      // Fire-and-forget — don't break feed if logging fails
    }
  }

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
  // PARENT-APPROVED CHANNELS
  // ==========================================

  /// Get list of channel IDs approved by a parent.
  Future<List<String>> getApprovedChannels(String parentId) async {
    final rows = await _client
        .from('parent_channel_prefs')
        .select('channel_id')
        .eq('parent_id', parentId)
        .eq('status', 'approved');

    return (rows as List).map((r) => r['channel_id'] as String).toList();
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  Future<void> _upsertVideo(VideoMetadata video) async {
    if (video.videoId.isEmpty) return;
    await _ingestVideoCacheEntry(video);
  }

  Future<void> ingestDiscoveredVideo(
    VideoMetadata video, {
    required String source,
    required String analysisStatus,
    required bool metadataGatePassed,
    String? metadataGateReason,
    double? metadataGateConfidence,
    DateTime? metadataCheckedAt,
    int? queuePriority,
    String? queueSource,
  }) async {
    await _ingestVideoCacheEntry(
      video,
      source: source,
      analysisStatus: analysisStatus,
      metadataGatePassed: metadataGatePassed,
      metadataGateReason: metadataGateReason,
      metadataGateConfidence: metadataGateConfidence,
      metadataCheckedAt: metadataCheckedAt,
      queuePriority: queuePriority,
      queueSource: queueSource,
    );
  }

  Future<void> _ingestVideoCacheEntry(
    VideoMetadata video, {
    String source = 'manual',
    String analysisStatus = 'pending',
    bool metadataGatePassed = false,
    String? metadataGateReason,
    double? metadataGateConfidence,
    DateTime? metadataCheckedAt,
    int? queuePriority,
    String? queueSource,
  }) async {
    final params = {
      'p_video_id': video.videoId,
      'p_title': video.title,
      'p_channel_id': video.channelId.isNotEmpty ? video.channelId : null,
      'p_channel_title': video.channelTitle.isNotEmpty
          ? video.channelTitle
          : null,
      'p_description': video.description,
      'p_thumbnail_url': video.thumbnailUrl,
      'p_duration_seconds': video.durationSeconds,
      'p_published_at': video.publishedAt?.toIso8601String(),
      'p_tags': video.tags,
      'p_category_id': video.categoryId,
      'p_has_captions': video.hasCaptions,
      'p_view_count': video.viewCount,
      'p_like_count': video.likeCount,
      'p_is_short': video.detectedAsShort,
      'p_discovery_source': source,
      'p_analysis_status': analysisStatus,
      'p_metadata_gate_passed': metadataGatePassed,
      'p_metadata_gate_reason': metadataGateReason,
      'p_queue_priority': queuePriority,
      'p_queue_source': queueSource,
      'p_is_embeddable': video.isEmbeddable,
      'p_privacy_status': video.privacyStatus,
      'p_made_for_kids': video.madeForKids,
      'p_last_playability_check_at': video.lastPlayabilityCheckAt
          ?.toIso8601String(),
      'p_metadata_gate_confidence':
          metadataGateConfidence ?? video.metadataGateConfidence,
      'p_metadata_checked_at': (metadataCheckedAt ?? video.metadataCheckedAt)
          ?.toIso8601String(),
    };

    try {
      await _client.rpc('ingest_video_cache_entry', params: params);
    } catch (e) {
      params.remove('p_is_embeddable');
      params.remove('p_privacy_status');
      params.remove('p_made_for_kids');
      params.remove('p_last_playability_check_at');
      params.remove('p_metadata_gate_confidence');
      params.remove('p_metadata_checked_at');
      try {
        await _client.rpc('ingest_video_cache_entry', params: params);
      } catch (fallbackError) {
        final summary = _summarizeIngestError(fallbackError);
        debugPrint(
          'VideoRepository: cache ingest skipped for ${video.videoId}: '
          '$summary',
        );
      }
    }
  }

  String _summarizeIngestError(Object error) {
    final message = error.toString();
    if (message.contains('PGRST203')) {
      return 'remote ingest RPC signature mismatch';
    }
    return message;
  }

  List<VideoMetadata> _filterPlayable(List<VideoMetadata> videos) {
    return videos
        .where(
          (video) =>
              video.isEmbeddable != false &&
              !PlayabilityCache.isBlocked(video.videoId),
        )
        .toList();
  }
}
