import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../domain/services/screen_time_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/duration_formatter.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../utils/thumbnail_preloader.dart';
import '../providers/kid_feed_provider.dart';
import '../widgets/parental_gate.dart';
import '../widgets/screen_time_indicator.dart';
import '../widgets/winddown_banner.dart';
import 'break_screen.dart';
import 'time_up_screen.dart';
import 'bedtime_screen.dart';

class KidHomeScreen extends ConsumerStatefulWidget {
  const KidHomeScreen({super.key});

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  bool _thumbnailsPreloaded = false;

  void _preloadThumbnails(List<FeedItem> items) {
    if (_thumbnailsPreloaded || !mounted) return;
    _thumbnailsPreloaded = true;

    final urls = items.map((i) => i.video.thumbnailUrl).toList();
    ThumbnailPreloader.preloadThumbnails(context, urls, maxPreload: 8);
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final feedAsync = ref.watch(kidFeedProvider);
    final categories = ref.watch(kidCategoriesProvider);
    final screenTime = ref.watch(screenTimeProvider);

    // Screen time overlays
    if (screenTime.status == ScreenTimeStatus.breakTime) {
      return BreakScreen(breakDurationSeconds: screenTime.breakDurationSeconds);
    }
    if (screenTime.status == ScreenTimeStatus.timeUp) {
      return TimeUpScreen(
        onParentOverride: () => context.goNamed(RouteNames.dashboard),
      );
    }
    if (screenTime.status == ScreenTimeStatus.bedtime ||
        screenTime.status == ScreenTimeStatus.beforeWakeup) {
      return BedtimeScreen(
        onParentOverride: () => context.goNamed(RouteNames.dashboard),
      );
    }

    return Theme(
      data: KidTheme.theme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5FF),
        body: SafeArea(
          child: Column(
            children: [
              // Winddown banner
              if (screenTime.status == ScreenTimeStatus.winddown)
                WinddownBanner(
                  minutesRemaining: screenTime.remainingMinutes ?? 5,
                ),

              // Top bar
              _KidTopBar(
                childName: child?.name ?? 'Kid',
                onExitTap: () => _handleExit(context),
                remainingMinutes: screenTime.remainingMinutes,
              ),

              // Category bubbles
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _CategoryBubble(
                      emoji: cat.emoji,
                      label: cat.label,
                      onTap: () {
                        // TODO: Filter feed by category
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Video feed
              Expanded(
                child: feedAsync.when(
                  data: (items) {
                    // Preload first batch of thumbnails
                    _preloadThumbnails(items);

                    if (items.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Preparing your videos...',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Check back soon!',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      cacheExtent: 300,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _KidVideoCard(
                          title: item.video.title,
                          thumbnailUrl: item.video.thumbnailUrl,
                          duration: item.video.durationSeconds,
                          onTap: () {
                            context.pushNamed(
                              RouteNames.kidPlayer,
                              pathParameters: {
                                'videoId': item.video.videoId,
                              },
                              queryParameters: {
                                'title': item.video.title,
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading videos...'),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Oops! Something went wrong.\n$e'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExit(BuildContext context) async {
    final passed = await showParentalGate(context);
    if (passed && context.mounted) {
      context.goNamed(RouteNames.dashboard);
    }
  }
}

class _KidTopBar extends StatelessWidget {
  final String childName;
  final VoidCallback onExitTap;
  final int? remainingMinutes;

  const _KidTopBar({
    required this.childName,
    required this.onExitTap,
    this.remainingMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.child_care, size: 32, color: Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          Text(
            'Hi, $childName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          // Screen time indicator
          ScreenTimeIndicator(minutesRemaining: remainingMinutes),
          const SizedBox(width: 8),
          // Hidden exit: long-press the settings icon
          GestureDetector(
            onLongPress: onExitTap,
            child: const Icon(
              Icons.settings,
              size: 20,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _CategoryBubble({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KidVideoCard extends StatelessWidget {
  final String title;
  final String thumbnailUrl;
  final int duration;
  final VoidCallback onTap;

  const _KidVideoCard({
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.play_circle_outline,
                                size: 40, color: Colors.grey),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image,
                                size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.play_circle_outline,
                              size: 40, color: Colors.grey),
                        ),
                  // Play button overlay
                  const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 44,
                      color: Colors.white70,
                    ),
                  ),
                  // Duration badge
                  if (duration > 0)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          DurationFormatter.videoLength(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
