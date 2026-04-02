import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/remote/piped_pool.dart';
import '../../data/datasources/remote/remote_config_service.dart';
import '../../data/datasources/remote/supabase_client.dart';
import '../../data/datasources/remote/youtube_api_client.dart';
import '../../data/models/video_metadata.dart';

/// Central orchestrator implementing the 4-tier YouTube data resolution chain:
///
/// ```
/// Tier 0: Cache (Supabase yt_videos/yt_channels) — 7-day TTL
/// Tier 1: YouTube Data API v3 (multi-key rotation)
/// Tier 2: Multi-instance Piped (health-checked cycling)
/// Tier 3: Stale cache fallback
/// ```
///
/// For trending/related: Piped first (free) → YouTube API → empty.
class YouTubeDataService {
  final YouTubeApiClient _ytClient;
  final PipedPool _pipedPool;
  final SupabaseClient _supabase;

  YouTubeDataService({
    YouTubeApiClient? ytClient,
    PipedPool? pipedPool,
    SupabaseClient? supabase,
  }) : _ytClient = ytClient ?? YouTubeApiClient(),
       _pipedPool = pipedPool ?? PipedPool(),
       _supabase = supabase ?? SupabaseClientWrapper.client;

  // ==========================================
  // PUBLIC API
  // ==========================================

  /// Search for videos.
  /// No cache (search results are too variable).
  /// Tier 1 → Tier 2 → empty.
  Future<VideoSearchResult> search(
    String query, {
    int maxResults = 20,
    String? pageToken,
  }) async {
    // Tier 1: YouTube API
    try {
      return await _ytClient.search(
        query,
        maxResults: maxResults,
        pageToken: pageToken,
      );
    } catch (e) {
      debugPrint('YouTubeDataService.search: YouTube API failed: $e');
    }

    // Tier 2: Piped
    try {
      return await _pipedPool.executeWithFailover(
        (client) => client.search(query),
      );
    } catch (e) {
      debugPrint('YouTubeDataService.search: Piped failed: $e');
    }

    return const VideoSearchResult(videos: []);
  }

  /// Get video details with full tier chain.
  Future<VideoMetadata> getVideoDetails(String videoId) async {
    // Tier 0: Fresh cache
    final cached = await _getCachedVideo(videoId);
    if (cached != null && _isFresh(cached)) return cached;

    // Tier 1: YouTube API
    try {
      final video = await _ytClient.getVideoDetails(videoId);
      _upsertVideoAsync(video);
      return video;
    } catch (e) {
      debugPrint('YouTubeDataService.getVideoDetails: YouTube API failed: $e');
    }

    // Tier 2: Piped
    try {
      final video = await _pipedPool.executeWithFailover(
        (client) => client.getVideoDetails(videoId),
      );
      _upsertVideoAsync(video);
      return video;
    } catch (e) {
      debugPrint('YouTubeDataService.getVideoDetails: Piped failed: $e');
    }

    // Tier 3: Stale cache
    if (cached != null) return cached;

    throw Exception('Video not found: $videoId');
  }

  /// Get multiple video details with cache optimization.
  Future<List<VideoMetadata>> getVideoDetailsBatch(
    List<String> videoIds,
  ) async {
    final results = <String, VideoMetadata>{};
    final uncachedIds = <String>[];

    // Tier 0: Check cache for each ID.
    for (final id in videoIds) {
      final cached = await _getCachedVideo(id);
      if (cached != null && _isFresh(cached)) {
        results[id] = cached;
      } else {
        uncachedIds.add(id);
      }
    }

    if (uncachedIds.isEmpty) {
      return videoIds.map((id) => results[id]!).toList();
    }

    // Tier 1: YouTube API (batch).
    try {
      final fetched = await _ytClient.getVideoDetailsBatch(uncachedIds);
      for (final v in fetched) {
        results[v.videoId] = v;
        uncachedIds.remove(v.videoId);
        _upsertVideoAsync(v);
      }
    } catch (e) {
      debugPrint(
        'YouTubeDataService.getVideoDetailsBatch: YouTube API failed: $e',
      );
    }

    // Tier 2: Piped (one-by-one for remaining).
    for (final id in List<String>.from(uncachedIds)) {
      try {
        final v = await _pipedPool.executeWithFailover(
          (client) => client.getVideoDetails(id),
        );
        results[v.videoId] = v;
        uncachedIds.remove(id);
        _upsertVideoAsync(v);
      } catch (_) {
        // Skip — will use stale cache or omit.
      }
    }

    // Tier 3: Stale cache for any still missing.
    for (final id in uncachedIds) {
      final stale = await _getCachedVideo(id);
      if (stale != null) results[id] = stale;
    }

    return videoIds
        .where((id) => results.containsKey(id))
        .map((id) => results[id]!)
        .toList();
  }

  /// Enrich lightweight discovery/search rows with full details when possible.
  Future<List<VideoMetadata>> enrichCandidates(
    List<VideoMetadata> candidates,
  ) async {
    final ids = candidates
        .map((candidate) => candidate.videoId)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return candidates;

    final fullDetails = await getVideoDetailsBatch(ids);
    final byId = {for (final video in fullDetails) video.videoId: video};

    return candidates
        .map((candidate) => byId[candidate.videoId] ?? candidate)
        .toList();
  }

  /// Get channel info with full tier chain.
  Future<ChannelMetadata> getChannelInfo(String channelId) async {
    // Tier 0: Fresh cache
    final cached = await _getCachedChannel(channelId);
    if (cached != null && _isChannelFresh(cached)) return cached;

    // Tier 1: YouTube API
    try {
      final channel = await _ytClient.getChannelInfo(channelId);
      _upsertChannelAsync(channel);
      return channel;
    } catch (e) {
      debugPrint('YouTubeDataService.getChannelInfo: YouTube API failed: $e');
    }

    // Tier 2: Piped
    try {
      final channel = await _pipedPool.executeWithFailover(
        (client) => client.getChannelInfo(channelId),
      );
      _upsertChannelAsync(channel);
      return channel;
    } catch (e) {
      debugPrint('YouTubeDataService.getChannelInfo: Piped failed: $e');
    }

    // Tier 3: Stale cache
    if (cached != null) return cached;

    throw Exception('Channel not found: $channelId');
  }

  /// Get channel videos (no cache — list is too variable).
  Future<List<VideoMetadata>> getChannelVideos(String channelId) async {
    // Tier 1: YouTube API
    try {
      return await _ytClient.getChannelVideos(channelId);
    } catch (e) {
      debugPrint('YouTubeDataService.getChannelVideos: YouTube API failed: $e');
    }

    // Tier 2: Piped
    try {
      return await _pipedPool.executeWithFailover(
        (client) => client.getChannelVideos(channelId),
      );
    } catch (e) {
      debugPrint('YouTubeDataService.getChannelVideos: Piped failed: $e');
    }

    return [];
  }

  /// Get trending videos.
  /// Prefer Piped first (free, no quota cost) → YouTube API → empty.
  Future<List<VideoMetadata>> getTrending({String region = 'US'}) async {
    // Tier 2 first: Piped (free)
    try {
      return await _pipedPool.executeWithFailover(
        (client) => client.getTrending(region: region),
      );
    } catch (e) {
      debugPrint('YouTubeDataService.getTrending: Piped failed: $e');
    }

    // Tier 1: YouTube API
    try {
      return await _ytClient.getTrending(region: region);
    } catch (e) {
      debugPrint('YouTubeDataService.getTrending: YouTube API failed: $e');
    }

    return [];
  }

  /// Get related videos.
  /// Prefer Piped first (free) → YouTube API (100 units!) → empty.
  Future<List<VideoMetadata>> getRelatedVideos(String videoId) async {
    // Tier 2 first: Piped (free)
    try {
      return await _pipedPool.executeWithFailover(
        (client) => client.getRelatedVideos(videoId),
      );
    } catch (e) {
      debugPrint('YouTubeDataService.getRelatedVideos: Piped failed: $e');
    }

    // Tier 1: YouTube API (expensive)
    try {
      return await _ytClient.getRelatedVideos(videoId);
    } catch (e) {
      debugPrint('YouTubeDataService.getRelatedVideos: YouTube API failed: $e');
    }

    return [];
  }

  // ==========================================
  // CACHE HELPERS
  // ==========================================

  Future<VideoMetadata?> _getCachedVideo(String videoId) async {
    try {
      final response = await _supabase
          .from('yt_videos')
          .select()
          .eq('video_id', videoId)
          .maybeSingle();
      if (response == null) return null;
      return VideoMetadata.fromSupabaseRow(response);
    } catch (_) {
      return null;
    }
  }

  Future<ChannelMetadata?> _getCachedChannel(String channelId) async {
    try {
      final response = await _supabase
          .from('yt_channels')
          .select()
          .eq('channel_id', channelId)
          .maybeSingle();
      if (response == null) return null;
      return ChannelMetadata.fromSupabaseRow(response);
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(VideoMetadata video) {
    if (video.lastFetchedAt == null) return false;
    return DateTime.now().difference(video.lastFetchedAt!) <
        RemoteConfigService.instance.videoTtl;
  }

  bool _isChannelFresh(ChannelMetadata channel) {
    if (channel.lastFetchedAt == null) return false;
    return DateTime.now().difference(channel.lastFetchedAt!) <
        RemoteConfigService.instance.channelTtl;
  }

  /// Fire-and-forget upsert of video metadata to cache.
  void _upsertVideoAsync(VideoMetadata video) {
    unawaited(_upsertVideoAsyncImpl(video));
  }

  Future<void> _upsertVideoAsyncImpl(VideoMetadata video) async {
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
      'p_discovery_source': 'cache_refresh',
      'p_analysis_status': video.analysisStatus ?? 'pending',
      'p_metadata_gate_passed': false,
      'p_is_embeddable': video.isEmbeddable,
      'p_privacy_status': video.privacyStatus,
      'p_made_for_kids': video.madeForKids,
      'p_last_playability_check_at': video.lastPlayabilityCheckAt
          ?.toIso8601String(),
    };

    try {
      await _supabase.rpc('ingest_video_cache_entry', params: params);
    } catch (e) {
      params.remove('p_is_embeddable');
      params.remove('p_privacy_status');
      params.remove('p_made_for_kids');
      params.remove('p_last_playability_check_at');

      try {
        await _supabase.rpc('ingest_video_cache_entry', params: params);
      } catch (fallbackError) {
        final summary = _summarizeCacheUpsertError(fallbackError);
        debugPrint(
          'YouTubeDataService: cache upsert skipped for ${video.videoId}: '
          '$summary',
        );
      }
    }
  }

  String _summarizeCacheUpsertError(Object error) {
    final message = error.toString();
    if (message.contains('PGRST203')) {
      return 'remote ingest RPC signature mismatch';
    }
    return message;
  }

  /// Fire-and-forget upsert of channel metadata to cache.
  void _upsertChannelAsync(ChannelMetadata channel) {
    _supabase
        .from('yt_channels')
        .upsert(channel.toSupabaseRow(), onConflict: 'channel_id')
        .then((_) {})
        .catchError((e) {
          debugPrint('YouTubeDataService: channel cache upsert failed: $e');
        });
  }
}
