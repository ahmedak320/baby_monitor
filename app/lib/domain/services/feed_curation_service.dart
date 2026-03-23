import 'dart:math';

import '../../data/models/video_metadata.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../utils/age_calculator.dart';
import 'content_filter_service.dart';

/// A curated feed item with metadata and filter result.
class FeedItem {
  final VideoMetadata video;
  final VideoAnalysis? analysis;
  final List<String> contentLabels;

  const FeedItem({
    required this.video,
    this.analysis,
    this.contentLabels = const [],
  });
}

/// Service that assembles an engaging, safe, and varied feed for a child.
class FeedCurationService {
  final VideoRepository _videoRepo;
  final ContentFilterService _filterService;

  FeedCurationService({
    VideoRepository? videoRepo,
    ContentFilterService? filterService,
  })  : _videoRepo = videoRepo ?? VideoRepository(),
        _filterService = filterService ?? ContentFilterService();

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
  }) async {
    final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);

    // Fetch approved videos
    final videos = await _videoRepo.getApprovedVideos(
      childId: child.id,
      childAge: childAge,
      limit: limit * 3, // fetch extra to allow filtering
    );

    final feedItems = <FeedItem>[];
    final usedCategories = <String>{};
    final recentSet = recentlyWatchedIds?.toSet() ?? {};

    for (final video in videos) {
      if (feedItems.length >= limit) break;

      // Skip recently watched
      if (recentSet.contains(video.videoId)) continue;

      // Get analysis
      final analysis = await _videoRepo.getAnalysis(video.videoId);
      if (analysis == null) continue;

      // Run filter
      final result = _filterService.filterForChild(
        analysis: analysis,
        child: child,
      );
      if (!result.isApproved) continue;

      // Check content type preferences and schedule
      final labels = analysis.contentLabels;
      if (allowedContentTypes != null && allowedContentTypes.isNotEmpty) {
        final hasAllowed = labels.any(
          (l) => allowedContentTypes.contains(l),
        );
        if (!hasAllowed && labels.isNotEmpty) continue;
      }

      // Check content preferences
      if (contentPreferences != null) {
        final isBlocked = labels.any(
          (l) => contentPreferences[l] == 'blocked',
        );
        if (isBlocked) continue;
      }

      feedItems.add(FeedItem(
        video: video,
        analysis: analysis,
        contentLabels: labels,
      ));
    }

    // Sort: preferred content first, then variety
    _sortForEngagement(feedItems, contentPreferences, usedCategories);

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
    final videos = await _videoRepo.getApprovedVideos(
      childId: child.id,
      childAge: childAge,
      limit: 20,
    );

    final suggestions = <FeedItem>[];

    for (final video in videos) {
      if (video.videoId == currentVideoId) continue;
      if (suggestions.length >= count) break;

      final analysis = await _videoRepo.getAnalysis(video.videoId);
      if (analysis == null) continue;

      final result = _filterService.filterForChild(
        analysis: analysis,
        child: child,
      );
      if (!result.isApproved) continue;

      suggestions.add(FeedItem(
        video: video,
        analysis: analysis,
        contentLabels: analysis.contentLabels,
      ));
    }

    // Prefer videos with overlapping content labels
    suggestions.sort((a, b) {
      final aOverlap =
          a.contentLabels.where((l) => currentLabels.contains(l)).length;
      final bOverlap =
          b.contentLabels.where((l) => currentLabels.contains(l)).length;
      return bOverlap.compareTo(aOverlap);
    });

    return suggestions.take(count).toList();
  }

  /// Sort feed items for engagement — mix preferred and variety.
  void _sortForEngagement(
    List<FeedItem> items,
    Map<String, String>? prefs,
    Set<String> usedCategories,
  ) {
    final rng = Random();

    items.sort((a, b) {
      // Preferred content gets a boost
      final aPreferred = prefs != null &&
          a.contentLabels.any((l) => prefs[l] == 'preferred');
      final bPreferred = prefs != null &&
          b.contentLabels.any((l) => prefs[l] == 'preferred');

      if (aPreferred && !bPreferred) return -1;
      if (!aPreferred && bPreferred) return 1;

      // Mix in some randomness to prevent staleness
      return rng.nextInt(3) - 1;
    });
  }
}
