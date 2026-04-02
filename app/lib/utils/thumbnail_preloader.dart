import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../data/models/video_metadata.dart';

/// Utility to preload thumbnail images for smoother feed scrolling.
class ThumbnailPreloader {
  ThumbnailPreloader._();

  static List<String> candidateUrls(String thumbnailUrl) {
    final normalized = thumbnailUrl.replaceAll('_live.jpg', '.jpg');
    final candidates = <String>{};
    void add(String url) {
      if (url.isNotEmpty) candidates.add(url);
    }

    add(normalized);
    add(normalized.replaceAll('/maxresdefault.jpg', '/hqdefault.jpg'));
    add(normalized.replaceAll('/maxresdefault.jpg', '/mqdefault.jpg'));
    add(normalized.replaceAll('/hqdefault.jpg', '/mqdefault.jpg'));
    add(normalized.replaceAll('/hqdefault.jpg', '/default.jpg'));
    add(normalized.replaceAll('/mqdefault.jpg', '/default.jpg'));

    return candidates.toList();
  }

  /// Preload a batch of thumbnail URLs into the image cache.
  /// Only preloads the first [maxPreload] items to avoid excessive memory usage.
  static Future<void> preloadThumbnails(
    BuildContext context,
    List<String> thumbnailUrls, {
    int maxPreload = 10,
  }) async {
    for (final url
        in thumbnailUrls.take(maxPreload).where((u) => u.isNotEmpty)) {
      for (final candidate in candidateUrls(url)) {
        try {
          await precacheImage(CachedNetworkImageProvider(candidate), context);
          break;
        } catch (_) {
          // Continue trying candidates until one resolves.
        }
      }
    }
  }

  static Future<void> preloadVideoThumbnails(
    BuildContext context,
    List<VideoMetadata> videos, {
    int maxPreload = 10,
  }) async {
    for (final video in videos.take(maxPreload)) {
      for (final candidate in candidateUrls(video.thumbnailUrl)) {
        try {
          await precacheImage(CachedNetworkImageProvider(candidate), context);
          break;
        } catch (_) {
          // Continue trying candidates until one resolves.
        }
      }
    }
  }
}
