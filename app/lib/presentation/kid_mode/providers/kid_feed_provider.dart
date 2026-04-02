import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/analysis_api.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../domain/services/video_discovery_service.dart';
import '../../../providers/current_child_provider.dart';

/// Provides the feed curation service.
final feedCurationProvider = Provider<FeedCurationService>((ref) {
  return FeedCurationService();
});

/// Provides the video discovery service.
final videoDiscoveryProvider = Provider<VideoDiscoveryService>((ref) {
  return VideoDiscoveryService();
});

/// Counter that increments when any analysis completes, triggering feed rebuild.
final analysisRefreshCounterProvider = StateProvider<int>((ref) {
  ref.listen(analysisCompletedStreamProvider, (_, next) {
    next.whenData((_) {
      ref.controller.state++;
    });
  });
  return 0;
});

/// Provides the curated feed for the current child.
/// Also triggers background discovery of trending content.
final kidFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final child = ref.watch(currentChildProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  // Rebuild when analysis completes (reactive filtering)
  ref.watch(analysisRefreshCounterProvider);
  if (child == null) return [];

  // Trigger trending discovery in background (rate-limited to 1x/hour)
  final discovery = ref.read(videoDiscoveryProvider);
  discovery.discoverTrending(); // fire and forget

  final service = ref.watch(feedCurationProvider);
  try {
    final feed = await service.buildFeed(
      child: child,
      includeMetadataApproved: true,
    );

    // Client-side category filter
    if (selectedCategory != null) {
      return feed
          .where(
            (item) =>
                item.contentLabels.contains(selectedCategory) ||
                (selectedCategory == 'shorts' && item.video.detectedAsShort),
          )
          .toList();
    }

    return feed;
  } catch (e) {
    // Log and return empty on error
    debugPrint('Feed build error: $e');
    return [];
  }
});

/// Provides "Up Next" suggestions after a video.
final upNextProvider =
    FutureProvider.family<
      List<FeedItem>,
      ({String videoId, List<String> labels})
    >((ref, params) async {
      final child = ref.watch(currentChildProvider);
      if (child == null) return [];

      // Discover related videos in background
      final discovery = ref.read(videoDiscoveryProvider);
      discovery.discoverRelated(params.videoId); // fire and forget

      final service = ref.watch(feedCurationProvider);
      return service.getUpNext(
        child: child,
        currentVideoId: params.videoId,
        currentLabels: params.labels,
      );
    });

/// Currently selected category filter (null = "All").
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Available content categories for the kid home screen.
final kidCategoriesProvider = Provider<List<ContentCategory>>((ref) {
  return const [
    ContentCategory(id: 'educational', label: 'Learning', emoji: '📚'),
    ContentCategory(id: 'nature', label: 'Animals', emoji: '🦁'),
    ContentCategory(id: 'cartoons', label: 'Cartoons', emoji: '🎬'),
    ContentCategory(id: 'music', label: 'Music', emoji: '🎵'),
    ContentCategory(id: 'storytime', label: 'Stories', emoji: '📖'),
    ContentCategory(id: 'fun', label: 'Fun', emoji: '🎉'),
    ContentCategory(id: 'soothing', label: 'Calm', emoji: '🌙'),
    ContentCategory(id: 'creative', label: 'Create', emoji: '🎨'),
    ContentCategory(id: 'shorts', label: 'Shorts', emoji: '⚡'),
  ];
});

class ContentCategory {
  final String id;
  final String label;
  final String emoji;

  const ContentCategory({
    required this.id,
    required this.label,
    required this.emoji,
  });
}
