import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../data/repositories/watch_history_repository.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/duration_formatter.dart';

/// Provider for the child's watch history.
final watchHistoryProvider =
    FutureProvider<List<WatchHistoryEntry>>((ref) async {
  final child = ref.watch(currentChildProvider);
  if (child == null) return [];

  final repo = WatchHistoryRepository();
  return repo.getHistory(childId: child.id, limit: 50);
});

/// Library tab showing watch history and liked videos.
class KidLibraryScreen extends ConsumerWidget {
  const KidLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryProvider);

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Library',
              style: TextStyle(
                color: KidTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Watch history section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history, color: KidTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Watch History',
                  style: TextStyle(
                    color: KidTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        historyAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 48, color: KidTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No videos watched yet',
                          style: TextStyle(color: KidTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  final video = entry.video;
                  if (video == null) return const SizedBox.shrink();

                  return _HistoryVideoTile(
                    title: video.title,
                    channelTitle: video.channelTitle,
                    thumbnailUrl: video.thumbnailUrl,
                    duration: video.durationSeconds,
                    watchedAt: entry.watchedAt,
                    onTap: () {
                      context.pushNamed(
                        RouteNames.kidPlayer,
                        pathParameters: {'videoId': video.videoId},
                        queryParameters: {'title': video.title},
                      );
                    },
                  );
                },
                childCount: entries.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Could not load history',
                  style: TextStyle(color: KidTheme.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryVideoTile extends StatelessWidget {
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final int duration;
  final DateTime watchedAt;
  final VoidCallback onTap;

  const _HistoryVideoTile({
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.duration,
    required this.watchedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 160,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: KidTheme.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl.replaceAll('_live.jpg', '.jpg'),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: KidTheme.surface),
                      errorWidget: (_, _, _) =>
                          Container(color: KidTheme.surface),
                    ),
                  if (duration > 0)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          DurationFormatter.videoLength(duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    channelTitle,
                    style: TextStyle(
                        color: KidTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(watchedAt),
                    style: TextStyle(
                        color: KidTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
