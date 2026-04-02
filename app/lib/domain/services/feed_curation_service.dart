import 'dart:math';

import '../../data/models/video_metadata.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../utils/age_calculator.dart';
import 'content_filter_service.dart';

/// A curated feed item with metadata and filter result.
class FeedItem {
  final VideoMetadata video;
  final VideoAnalysis? analysis;
  final List<String> contentLabels;
  final bool isPendingAnalysis;

  const FeedItem({
    required this.video,
    this.analysis,
    this.contentLabels = const [],
    this.isPendingAnalysis = false,
  });
}

/// Service that assembles an engaging, safe, and varied feed for a child.
class FeedCurationService {
  final VideoRepository _videoRepo;
  final ContentFilterService _filterService;
  final ChannelRepository _channelRepo;

  FeedCurationService({
    VideoRepository? videoRepo,
    ContentFilterService? filterService,
    ChannelRepository? channelRepo,
  }) : _videoRepo = videoRepo ?? VideoRepository(),
       _filterService = filterService ?? ContentFilterService(),
       _channelRepo = channelRepo ?? ChannelRepository();

  /// Build a curated feed for a child.
  ///
  /// Balances: variety (rotate categories), freshness, engagement,
  /// and respects content preferences and schedule.
  Future<List<FeedItem>> buildFeed({
    required ChildProfile child,
    Map<String, String>? contentPreferences,
    List<String>? allowedContentTypes, // from schedule, if active
    List<String>? recentlyWatchedIds,
    int limit = 30,
    bool includeMetadataApproved = false,
  }) async {
    final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);
    final history = await _videoRepo.getWatchHistory(child.id, limit: 20);
    final fallbackRecentIds = history
        .map(_extractHistoryVideoId)
        .whereType<String>()
        .toList();
    final effectiveRecentIds = recentlyWatchedIds ?? fallbackRecentIds;

    // Fetch parent's channel preferences for filtering
    final channelPrefs = await _channelRepo.getChannelPrefsMap(child.parentId);

    // Fetch approved videos (optionally including metadata-approved)
    List<VideoMetadata> videos;
    try {
      videos = await _videoRepo.getApprovedVideos(
        childId: child.id,
        childAge: childAge,
        limit: limit * 3,
        includeMetadataApproved: includeMetadataApproved,
        includePending: false,
      );
    } catch (e) {
      // Fallback: try without metadata-approved if query fails
      // (e.g., migration 004 not run yet)
      try {
        videos = await _videoRepo.getApprovedVideos(
          childId: child.id,
          childAge: childAge,
          limit: limit * 3,
          includeMetadataApproved: false,
        );
      } catch (_) {
        return [];
      }
    }
    final feedItems = <FeedItem>[];
    final recentSet = effectiveRecentIds.toSet();
    final recentChannelCounts = <String, int>{};
    for (final row in history) {
      final joined = row['yt_videos'];
      if (joined is Map<String, dynamic>) {
        final channelId = joined['channel_id'] as String?;
        if (channelId != null && channelId.isNotEmpty) {
          recentChannelCounts[channelId] =
              (recentChannelCounts[channelId] ?? 0) + 1;
        }
      }
    }

    for (final video in videos) {
      if (feedItems.length >= limit) break;

      // Skip recently watched
      if (recentSet.contains(video.videoId)) continue;
      if (channelPrefs[video.channelId] == 'blocked') continue;

      // Get analysis (may be null for metadata-approved videos)
      final analysis = await _videoRepo.getAnalysis(video.videoId);

      // If we have analysis, run the content filter
      if (analysis != null) {
        final result = _filterService.filterForChild(
          analysis: analysis,
          child: child,
          channelId: video.channelId,
          channelPrefs: channelPrefs,
        );
        if (!result.isApproved) {
          // Log the filtered video for parent dashboard visibility
          _videoRepo.logFiltered(
            childId: child.id,
            videoId: video.videoId,
            reason: result.reason,
          );
          continue;
        }
      }
      // No analysis yet — show the video (whitelist-until-checked).
      // It will be filtered reactively once analysis completes.

      // Check content type preferences and schedule
      final labels = analysis?.contentLabels ?? [];
      if (allowedContentTypes != null && allowedContentTypes.isNotEmpty) {
        final hasAllowed = labels.any((l) => allowedContentTypes.contains(l));
        if (!hasAllowed && labels.isNotEmpty) continue;
      }

      // Check content preferences
      if (contentPreferences != null) {
        final isBlocked = labels.any((l) => contentPreferences[l] == 'blocked');
        if (isBlocked) continue;
      }

      feedItems.add(
        FeedItem(
          video: video,
          analysis: analysis,
          contentLabels: labels,
          isPendingAnalysis: analysis == null,
        ),
      );
    }

    // Sort: preferred content first, then variety
    _sortForEngagement(feedItems, contentPreferences, recentChannelCounts);

    return feedItems;
  }

  /// Get "Up Next" suggestions after a video ends.
  Future<List<FeedItem>> getUpNext({
    required ChildProfile child,
    required String currentVideoId,
    required List<String> currentLabels,
    int count = 3,
  }) async {
    final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);
    final channelPrefs = await _channelRepo.getChannelPrefsMap(child.parentId);
    final videos = await _videoRepo.getApprovedVideos(
      childId: child.id,
      childAge: childAge,
      limit: 20,
      includeMetadataApproved: true,
      includePending: false,
    );

    final suggestions = <FeedItem>[];

    for (final video in videos) {
      if (video.videoId == currentVideoId) continue;
      if (suggestions.length >= count) break;

      final analysis = await _videoRepo.getAnalysis(video.videoId);
      if (channelPrefs[video.channelId] == 'blocked') continue;

      // If analyzed, run content filter; if not, allow through
      if (analysis != null) {
        final result = _filterService.filterForChild(
          analysis: analysis,
          child: child,
          channelId: video.channelId,
          channelPrefs: channelPrefs,
        );
        if (!result.isApproved) {
          _videoRepo.logFiltered(
            childId: child.id,
            videoId: video.videoId,
            reason: result.reason,
          );
          continue;
        }
      }

      suggestions.add(
        FeedItem(
          video: video,
          analysis: analysis,
          contentLabels: analysis?.contentLabels ?? [],
          isPendingAnalysis: analysis == null,
        ),
      );
    }

    // Prefer videos with overlapping content labels
    suggestions.sort((a, b) {
      final aOverlap = a.contentLabels
          .where((l) => currentLabels.contains(l))
          .length;
      final bOverlap = b.contentLabels
          .where((l) => currentLabels.contains(l))
          .length;
      if (aOverlap != bOverlap) {
        return bOverlap.compareTo(aOverlap);
      }
      return _engagementScore(
        b,
        null,
        const {},
      ).compareTo(_engagementScore(a, null, const {}));
    });

    return _spreadChannels(suggestions).take(count).toList();
  }

  /// Get videos from parent-approved channels.
  Future<List<FeedItem>> getApprovedChannelVideos({
    required ChildProfile child,
    int limit = 15,
  }) async {
    try {
      final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);

      // Fetch parent's approved channels
      final approvedChannels = await _videoRepo.getApprovedChannels(
        child.parentId,
      );
      if (approvedChannels.isEmpty) return [];

      // Fetch all approved videos and filter to approved channels
      final allVideos = await _videoRepo.getApprovedVideos(
        childId: child.id,
        childAge: childAge,
        limit: limit * 3,
        includeMetadataApproved: true,
      );

      final channelPrefs = await _channelRepo.getChannelPrefsMap(
        child.parentId,
      );
      final channelSet = approvedChannels.toSet();
      final channelVideos = allVideos
          .where((v) => channelSet.contains(v.channelId))
          .toList();

      final items = <FeedItem>[];
      for (final video in channelVideos) {
        if (items.length >= limit) break;
        final analysis = await _videoRepo.getAnalysis(video.videoId);
        if (analysis != null) {
          final result = _filterService.filterForChild(
            analysis: analysis,
            child: child,
            channelId: video.channelId,
            channelPrefs: channelPrefs,
          );
          if (!result.isApproved) {
            _videoRepo.logFiltered(
              childId: child.id,
              videoId: video.videoId,
              reason: result.reason,
            );
            continue;
          }
        }
        items.add(
          FeedItem(
            video: video,
            analysis: analysis,
            contentLabels: analysis?.contentLabels ?? [],
          ),
        );
      }
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Sort feed items for engagement — mix preferred and variety.
  void _sortForEngagement(
    List<FeedItem> items,
    Map<String, String>? prefs,
    Map<String, int> recentChannelCounts,
  ) {
    items.sort((a, b) {
      final scoreDelta = _engagementScore(
        b,
        prefs,
        recentChannelCounts,
      ).compareTo(_engagementScore(a, prefs, recentChannelCounts));
      if (scoreDelta != 0) return scoreDelta;

      return a.video.title.compareTo(b.video.title);
    });

    final spread = _spreadChannels(items);
    items
      ..clear()
      ..addAll(spread);
  }

  double _engagementScore(
    FeedItem item,
    Map<String, String>? prefs,
    Map<String, int> recentChannelCounts,
  ) {
    var score = 0.0;
    final video = item.video;

    final isPreferred =
        prefs != null &&
        item.contentLabels.any((label) => prefs[label] == 'preferred');
    if (isPreferred) score += 4;

    if (!item.isPendingAnalysis) {
      score += 2;
    } else {
      score += 0.75;
    }

    if (video.viewCount > 0) {
      score += log(video.viewCount + 1) / ln10;
    }

    if (video.publishedAt != null) {
      final ageInDays = DateTime.now().difference(video.publishedAt!).inDays;
      score += max(0, 3 - (ageInDays / 7));
    }

    if (video.durationSeconds > 0 && video.durationSeconds <= 20 * 60) {
      score += 0.5;
    }

    score -= (recentChannelCounts[video.channelId] ?? 0) * 0.9;
    score += item.contentLabels.isNotEmpty
        ? min(item.contentLabels.length, 2) * 0.25
        : 0;

    return score;
  }

  List<FeedItem> _spreadChannels(List<FeedItem> items) {
    if (items.length < 3) return items;

    final remaining = List<FeedItem>.from(items);
    final ordered = <FeedItem>[];
    String? lastChannelId;

    while (remaining.isNotEmpty) {
      final nextIndex = remaining.indexWhere(
        (item) => item.video.channelId != lastChannelId,
      );
      final selected = remaining.removeAt(nextIndex == -1 ? 0 : nextIndex);
      ordered.add(selected);
      lastChannelId = selected.video.channelId;
    }

    return ordered;
  }

  String? _extractHistoryVideoId(Map<String, dynamic> row) {
    final direct = row['video_id'];
    if (direct is String && direct.isNotEmpty) return direct;

    final joined = row['yt_videos'];
    if (joined is Map<String, dynamic>) {
      final nested = joined['video_id'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }
}
