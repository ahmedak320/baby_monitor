import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/theme/kid_theme.dart';
import '../../../domain/services/feed_curation_service.dart';

/// A single Short in the vertical swipe feed.
/// Displays the video thumbnail/player with overlays for creator info,
/// action buttons, and safety badge.
class ShortsPlayerWidget extends StatelessWidget {
  final FeedItem item;
  final int? remainingMinutes;
  final VoidCallback onTap;

  const ShortsPlayerWidget({
    super.key,
    required this.item,
    this.remainingMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: video thumbnail
          _VideoBackground(thumbnailUrl: item.video.thumbnailUrl),

          // Play button overlay
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              size: 72,
              color: Colors.white54,
            ),
          ),

          // Screen time pill (top right)
          if (remainingMinutes != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${remainingMinutes}m',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right side action buttons
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: Icons.favorite_border,
                  label: '',
                  onTap: () {
                    // Cosmetic like — stored locally for recommendations
                  },
                ),
                const SizedBox(height: 16),
                _ActionButton(icon: Icons.more_vert, label: '', onTap: () {}),
              ],
            ),
          ),

          // Bottom info overlay
          Positioned(
            left: 0,
            right: 60,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Channel name
                  Text(
                    item.video.channelTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Video title
                  Text(
                    item.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  // Safety badge + content label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Safe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.contentLabels.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KidTheme.youtubeRed.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.contentLabels.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoBackground extends StatelessWidget {
  final String thumbnailUrl;

  const _VideoBackground({required this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl.isEmpty) {
      return Container(color: KidTheme.background);
    }
    return CachedNetworkImage(
      imageUrl: thumbnailUrl.replaceAll('_live.jpg', '.jpg'),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: KidTheme.background),
      errorWidget: (_, _, _) => Container(color: KidTheme.background),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
