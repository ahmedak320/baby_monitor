import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../data/datasources/local/preferences_cache.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../domain/services/parental_control_service.dart';
import '../../../domain/services/screen_time_service.dart';
import '../../../domain/services/feed_curation_service.dart';
import '../../../providers/current_child_provider.dart';
import '../../../routing/route_names.dart';
import '../../../utils/age_calculator.dart';
import '../../../utils/duration_formatter.dart';
import '../../../utils/thumbnail_preloader.dart';
import '../providers/kid_feed_provider.dart';
import '../providers/shorts_feed_provider.dart';
import '../widgets/winddown_banner.dart';
import 'break_screen.dart';
import 'time_up_screen.dart';
import 'bedtime_screen.dart';
import 'shorts_feed_screen.dart';
import 'kid_library_screen.dart';
import 'kid_profile_screen.dart';

/// YouTube-mirror kid mode with 4-tab bottom navigation.
class KidHomeScreen extends ConsumerStatefulWidget {
  const KidHomeScreen({super.key});

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _rehydrateCurrentChild();
  }

  Future<void> _rehydrateCurrentChild() async {
    if (ref.read(currentChildProvider) != null) return;

    final lastChildId = PreferencesCache.lastChildId;
    if (lastChildId == null) return;

    try {
      final children = await ProfileRepository().getChildren();
      ChildProfile? match;
      for (final child in children) {
        if (child.id == lastChildId) {
          match = child;
          break;
        }
      }
      if (match != null && mounted) {
        ref.read(currentChildProvider.notifier).setChild(match);
      }
    } catch (_) {
      // Leave state unset; downstream providers already handle null safely.
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenTime = ref.watch(screenTimeProvider);

    final currentChild = ref.watch(currentChildProvider);
    final childAge = currentChild != null
        ? AgeCalculator.yearsFromDob(currentChild.dateOfBirth)
        : 5;

    // Screen time overlays take priority
    if (screenTime.status == ScreenTimeStatus.breakTime) {
      return BreakScreen(breakDurationSeconds: screenTime.breakDurationSeconds);
    }
    if (screenTime.status == ScreenTimeStatus.timeUp) {
      return TimeUpScreen(
        childAge: childAge,
        onParentOverride: () async {
          await ParentalControlService.exitKidMode();
          if (context.mounted) context.goNamed(RouteNames.dashboard);
        },
      );
    }
    if (screenTime.status == ScreenTimeStatus.bedtime ||
        screenTime.status == ScreenTimeStatus.beforeWakeup) {
      return BedtimeScreen(
        childAge: childAge,
        onParentOverride: () async {
          await ParentalControlService.exitKidMode();
          if (context.mounted) context.goNamed(RouteNames.dashboard);
        },
      );
    }

    return Theme(
      data: KidTheme.theme,
      child: Scaffold(
        backgroundColor: KidTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Winddown banner
              if (screenTime.status == ScreenTimeStatus.winddown)
                WinddownBanner(
                  minutesRemaining: screenTime.remainingMinutes ?? 5,
                ),

              // Tab content
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: const [
                    _HomeTabContent(),
                    ShortsFeedScreen(),
                    KidLibraryScreen(),
                    KidProfileScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: KidTheme.theme,
          child: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (index) => setState(() => _currentTab = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.electric_bolt_outlined),
                activeIcon: Icon(Icons.electric_bolt),
                label: 'Shorts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.video_library_outlined),
                activeIcon: Icon(Icons.video_library),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'You',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home tab content — search bar, Shorts preview row, categories, video grid.
class _HomeTabContent extends ConsumerStatefulWidget {
  const _HomeTabContent();

  @override
  ConsumerState<_HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends ConsumerState<_HomeTabContent> {
  bool _thumbnailsPreloaded = false;

  void _preloadThumbnails(List<FeedItem> items) {
    if (_thumbnailsPreloaded || !mounted) return;
    _thumbnailsPreloaded = true;
    final urls = items.map((i) => i.video.thumbnailUrl).toList();
    ThumbnailPreloader.preloadThumbnails(context, urls, maxPreload: 8);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(kidFeedProvider);
    final shortsAsync = ref.watch(shortsFeedProvider);
    final categories = ref.watch(kidCategoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GestureDetector(
              onTap: () => context.pushNamed(RouteNames.kidSearch),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KidTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: KidTheme.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: KidTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.mic, color: KidTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Shorts preview row
        shortsAsync.when(
          data: (shorts) {
            if (shorts.isEmpty)
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.electric_bolt,
                          color: KidTheme.youtubeRed,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Shorts',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: shorts.length.clamp(0, 10),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = shorts[index];
                        return _ShortsPreviewCard(
                          item: item,
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
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // Category chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat.id;
                return _CategoryChip(
                  label: cat.label,
                  emoji: cat.emoji,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(selectedCategoryProvider.notifier).state =
                        isSelected ? null : cat.id;
                  },
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Video feed grid
        feedAsync.when(
          data: (items) {
            _preloadThumbnails(items);

            if (items.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 64,
                        color: KidTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparing your videos...',
                        style: TextStyle(
                          fontSize: 16,
                          color: KidTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return _YouTubeVideoCard(
                  item: item,
                  onTap: () {
                    context.pushNamed(
                      RouteNames.kidPlayer,
                      pathParameters: {'videoId': item.video.videoId},
                      queryParameters: {'title': item.video.title},
                    );
                  },
                );
              }, childCount: items.length),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(
              child: Text(
                'Something went wrong',
                style: TextStyle(color: KidTheme.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shorts preview card (tall thumbnail) for the home tab horizontal scroll.
class _ShortsPreviewCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const _ShortsPreviewCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: KidTheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.video.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.video.thumbnailUrl.replaceAll(
                  '_live.jpg',
                  '.jpg',
                ),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: KidTheme.surface),
                errorWidget: (_, _, _) => Container(color: KidTheme.surface),
              ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  item.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// YouTube-style category chip.
class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : KidTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            color: isSelected ? Colors.black : KidTheme.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// YouTube-style video card for the main feed.
class _YouTubeVideoCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const _YouTubeVideoCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: KidTheme.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.video.thumbnailUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: item.video.thumbnailUrl.replaceAll(
                          '_live.jpg',
                          '.jpg',
                        ),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: KidTheme.surface),
                        errorWidget: (_, _, _) => Container(
                          color: KidTheme.surface,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    // Duration badge
                    if (item.video.durationSeconds > 0)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            DurationFormatter.videoLength(
                              item.video.durationSeconds,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    // Analyzing badge for unchecked videos
                    if (item.isPendingAnalysis)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.amber,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Checking...',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Video info row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: KidTheme.surfaceVariant,
                  child: Text(
                    item.video.channelTitle.isNotEmpty
                        ? item.video.channelTitle[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and channel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.video.channelTitle,
                        style: TextStyle(
                          color: KidTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
