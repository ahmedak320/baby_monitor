import '../../data/datasources/remote/supabase_client.dart';
import '../../data/models/video_metadata.dart';
import '../../data/repositories/video_repository.dart';
import 'metadata_gate_service.dart';
import 'youtube_data_service.dart';

/// Orchestrates video discovery from multiple sources:
/// trending, related, search, and parent submissions.
class VideoDiscoveryService {
  final YouTubeDataService _ytService;
  final VideoRepository _videoRepo;

  DateTime? _lastTrendingFetch;
  static const _trendingCooldown = Duration(hours: 1);
  static const _shortQueries = [
    'kids shorts songs',
    'educational shorts for kids',
    'animal shorts for kids',
  ];
  static const _trendingQueries = [
    'nursery rhymes for kids',
    'educational videos for kids',
    'science for kids',
    'animal videos for kids',
  ];

  VideoDiscoveryService({
    YouTubeDataService? ytService,
    VideoRepository? videoRepo,
  }) : _ytService = ytService ?? YouTubeDataService(),
       _videoRepo = videoRepo ?? VideoRepository();

  /// Fetch trending kids content. Rate-limited to once per hour.
  Future<List<VideoMetadata>> discoverTrending() async {
    if (_lastTrendingFetch != null &&
        DateTime.now().difference(_lastTrendingFetch!) < _trendingCooldown) {
      return [];
    }
    _lastTrendingFetch = DateTime.now();

    final discovered = <String, VideoMetadata>{};
    for (final query in _trendingQueries) {
      try {
        final result = await _ytService.search(query, maxResults: 8);
        for (final video in result.videos) {
          discovered[video.videoId] = video;
        }
      } catch (_) {
        // Continue trying the next curated query.
      }
    }

    if (discovered.isEmpty) return [];
    final enriched = await _ytService.enrichCandidates(
      discovered.values.toList(),
    );
    return _ingestVideos(enriched, 'curated_trending');
  }

  /// Fetch related/sidebar videos for a given video.
  Future<List<VideoMetadata>> discoverRelated(String videoId) async {
    try {
      final videos = await _ytService.getRelatedVideos(videoId);
      final enriched = await _ytService.enrichCandidates(videos);
      return _ingestVideos(enriched, 'related');
    } catch (_) {
      return [];
    }
  }

  /// Fetch short-form videos when the Shorts feed is empty.
  Future<List<VideoMetadata>> discoverShorts() async {
    final discovered = <String, VideoMetadata>{};

    for (final query in _shortQueries) {
      try {
        final result = await _ytService.search(query, maxResults: 12);
        for (final video in result.videos) {
          discovered[video.videoId] = video;
        }
      } catch (_) {
        // Continue to the next query.
      }
    }

    if (discovered.isEmpty) return [];
    final enriched = await _ytService.enrichCandidates(
      discovered.values.toList(),
    );
    final shorts = enriched.where((v) => v.detectedAsShort).toList();
    if (shorts.isEmpty) return [];
    return _ingestVideos(shorts, 'shorts_discovery');
  }

  /// Submit a YouTube link from a parent.
  Future<void> submitParentLink({
    required String videoUrl,
    required String action,
  }) async {
    final videoId = parseVideoId(videoUrl);
    if (videoId == null) return;

    final userId = SupabaseClientWrapper.currentUserId;

    // Record submission
    await SupabaseClientWrapper.client.from('parent_link_submissions').insert({
      'parent_id': userId,
      'video_url': videoUrl,
      'video_id': videoId,
      'action': action,
      'status': action == 'analyze' ? 'processing' : 'completed',
    });

    if (action == 'approve' || action == 'block') {
      // Direct override — no analysis needed
      await SupabaseClientWrapper.client.from('parent_video_overrides').upsert({
        'parent_id': userId,
        'video_id': videoId,
        'status': action == 'approve' ? 'approved' : 'blocked',
      });
      return;
    }

    // Fetch video metadata and queue for analysis
    try {
      final video = await _ytService.getVideoDetails(videoId);
      await _videoRepo.ingestDiscoveredVideo(
        video,
        source: 'parent_submitted',
        analysisStatus: 'pending',
        metadataGatePassed: false,
        queuePriority: 3,
        queueSource: 'parent',
      );
    } catch (_) {
      // Video might not exist or API failed
    }
  }

  /// Ingest a list of videos: upsert, run metadata gate, queue for analysis.
  Future<List<VideoMetadata>> _ingestVideos(
    List<VideoMetadata> videos,
    String source,
  ) async {
    final ingested = <VideoMetadata>[];

    for (final video in videos) {
      if (video.videoId.isEmpty) continue;

      // Run metadata gate
      final gate = MetadataGateService.check(
        title: video.title,
        channelTitle: video.channelTitle,
        description: video.description,
        durationSeconds: video.durationSeconds,
        tags: video.tags,
        categoryId: video.categoryId,
        madeForKids: video.madeForKids ?? false,
      );

      // Upsert to database
      final status = gate.passed ? 'metadata_approved' : 'pending';
      await _videoRepo.ingestDiscoveredVideo(
        video,
        source: source,
        analysisStatus: status,
        metadataGatePassed: gate.passed,
        metadataGateReason: gate.reason,
        metadataGateConfidence: gate.confidence,
        metadataCheckedAt: DateTime.now(),
        queuePriority: source == 'search' ? 2 : (source == 'related' ? 5 : 8),
        queueSource: source,
      );

      ingested.add(video);
    }

    return ingested;
  }

  /// Parse a YouTube video ID from various URL formats.
  static String? parseVideoId(String url) {
    // youtube.com/watch?v=ID
    final watchMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);

    // youtu.be/ID
    final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);

    // youtube.com/shorts/ID
    final shortsMatch = RegExp(r'shorts/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (shortsMatch != null) return shortsMatch.group(1);

    // youtube.com/embed/ID
    final embedMatch = RegExp(r'embed/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (embedMatch != null) return embedMatch.group(1);

    // Raw video ID (11 chars)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) return url;

    return null;
  }
}
