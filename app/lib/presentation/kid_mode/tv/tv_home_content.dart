import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../routing/route_names.dart';
import 'tv_focusable.dart';

/// TV home screen content: horizontal swimlane rows of video cards.
class TvHomeContent extends StatelessWidget {
  const TvHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder categories — in production these come from FeedCurationService
    return const CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(left: 24, top: 16, bottom: 24),
            child: Text(
              'Baby Monitor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: KidTheme.textPrimary,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _TvVideoRow(title: 'Recommended for You')),
        SliverToBoxAdapter(child: _TvVideoRow(title: 'Popular Kids Channels')),
        SliverToBoxAdapter(child: _TvVideoRow(title: 'Educational')),
        SliverToBoxAdapter(child: _TvVideoRow(title: 'Music & Nursery Rhymes')),
      ],
    );
  }
}

class _TvVideoRow extends StatelessWidget {
  final String title;

  const _TvVideoRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: KidTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 10, // placeholder count
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TvFocusable(
                    autofocus: index == 0 && title == 'Recommended for You',
                    onSelect: () {
                      // Navigate to video player — placeholder
                      context.pushNamed(
                        RouteNames.kidPlayer,
                        pathParameters: {'videoId': 'placeholder_$index'},
                        queryParameters: {'title': '$title Video ${index + 1}'},
                      );
                    },
                    child: SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          Container(
                            width: 280,
                            height: 158,
                            decoration: BoxDecoration(
                              color: KidTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 48,
                                color: KidTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$title ${index + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: KidTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
