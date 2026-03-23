import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/feed_curation_service.dart';
import '../../../providers/current_child_provider.dart';

/// Provides the feed curation service.
final feedCurationProvider = Provider<FeedCurationService>((ref) {
  return FeedCurationService();
});

/// Provides the curated feed for the current child.
final kidFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final child = ref.watch(currentChildProvider);
  if (child == null) return [];

  final service = ref.watch(feedCurationProvider);
  return service.buildFeed(child: child);
});

/// Provides "Up Next" suggestions after a video.
final upNextProvider =
    FutureProvider.family<List<FeedItem>, ({String videoId, List<String> labels})>(
  (ref, params) async {
    final child = ref.watch(currentChildProvider);
    if (child == null) return [];

    final service = ref.watch(feedCurationProvider);
    return service.getUpNext(
      child: child,
      currentVideoId: params.videoId,
      currentLabels: params.labels,
    );
  },
);

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
