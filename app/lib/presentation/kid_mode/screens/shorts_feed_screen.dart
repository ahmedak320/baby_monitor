import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../domain/services/screen_time_service.dart';
import '../../../routing/route_names.dart';
import '../../../utils/platform_info.dart';
import '../../../utils/thumbnail_preloader.dart';
import '../providers/shorts_feed_provider.dart';
import '../widgets/shorts_player_widget.dart';

/// Full-screen vertical swipe Shorts feed, mirroring YouTube Shorts.
class ShortsFeedScreen extends ConsumerStatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  ConsumerState<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends ConsumerState<ShortsFeedScreen> {
  final _pageController = PageController();
  int _lastPreloadedIndex = -1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  KeyEventResult _handleTvKey(FocusNode node, KeyEvent event) {
    if (!PlatformInfo.isTV || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final shortsAsync = ref.watch(shortsFeedProvider);
    final screenTime = ref.watch(screenTimeProvider);

    return shortsAsync.when(
      data: (shorts) {
        _preloadLookahead(shorts, 0);
        if (shorts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.electric_bolt,
                  size: 64,
                  color: KidTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Shorts available yet',
                  style: TextStyle(fontSize: 18, color: KidTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back soon!',
                  style: TextStyle(fontSize: 14, color: KidTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Focus(
          autofocus: PlatformInfo.isTV,
          onKeyEvent: _handleTvKey,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: shorts.length + 1, // +1 for end card
            onPageChanged: (index) {
              _preloadLookahead(shorts, index);
              if (index + 10 >= shorts.length) {
                ref.invalidate(shortsFeedProvider);
              }
            },
            itemBuilder: (context, index) {
              if (index >= shorts.length) {
                // End card
                return Container(
                  color: KidTheme.background,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: KidTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(
                            fontSize: 18,
                            color: KidTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'More Shorts coming soon',
                          style: TextStyle(
                            fontSize: 14,
                            color: KidTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = shorts[index];
              return ShortsPlayerWidget(
                item: item,
                remainingMinutes: screenTime.remainingMinutes,
                onTap: () {
                  context.pushNamed(
                    RouteNames.kidPlayer,
                    pathParameters: {'videoId': item.video.videoId},
                    queryParameters: {
                      'title': item.video.title,
                      'isShort': 'true',
                    },
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Something went wrong',
          style: TextStyle(color: KidTheme.textSecondary),
        ),
      ),
    );
  }

  void _preloadLookahead(List<FeedItem> shorts, int startIndex) {
    if (!mounted || startIndex <= _lastPreloadedIndex) return;
    _lastPreloadedIndex = startIndex;
    final window = shorts
        .skip(startIndex)
        .take(11)
        .map((item) => item.video)
        .toList();
    ThumbnailPreloader.preloadVideoThumbnails(
      context,
      window,
      maxPreload: window.length,
    );
  }
}
