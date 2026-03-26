import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Utility to preload thumbnail images for smoother feed scrolling.
class ThumbnailPreloader {
  ThumbnailPreloader._();

  /// Preload a batch of thumbnail URLs into the image cache.
  /// Only preloads the first [maxPreload] items to avoid excessive memory usage.
  static Future<void> preloadThumbnails(
    BuildContext context,
    List<String> thumbnailUrls, {
    int maxPreload = 10,
  }) async {
    final urls = thumbnailUrls
        .take(maxPreload)
        .where((u) => u.isNotEmpty)
        .map((u) => u.replaceAll('_live.jpg', '.jpg'));

    for (final url in urls) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
        );
      } catch (_) {
        // Skip failed preloads — they'll load normally when visible
      }
    }
  }
}
