import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../data/models/video_metadata.dart';

/// Utility to preload thumbnail images for smoother feed scrolling.
class ThumbnailPreloader {
  ThumbnailPreloader._();

  static String normalizeUrl(String thumbnailUrl) {
    final trimmed = thumbnailUrl.trim();
    if (trimmed.isEmpty) return '';

    var normalized = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
    if (normalized.contains('/hq_live.jpg')) {
      normalized = normalized.replaceAll('/hq_live.jpg', '/hqdefault_live.jpg');
    }
    return normalized;
  }

  static List<String> candidateUrls(String thumbnailUrl) {
    final normalized = normalizeUrl(thumbnailUrl);
    if (normalized.isEmpty) return const [];

    final candidates = <String>{};
    void add(String url) {
      if (url.isNotEmpty) candidates.add(url);
    }

    add(normalized);
    if (_isYouTubeThumbnail(normalized)) {
      final withoutLive = normalized.replaceAll('_live.jpg', '.jpg');
      add(withoutLive);
      add(withoutLive.replaceAll('/maxresdefault.jpg', '/sddefault.jpg'));
      add(withoutLive.replaceAll('/maxresdefault.jpg', '/hqdefault.jpg'));
      add(withoutLive.replaceAll('/maxresdefault.jpg', '/mqdefault.jpg'));
      add(withoutLive.replaceAll('/maxresdefault.jpg', '/default.jpg'));
      add(withoutLive.replaceAll('/sddefault.jpg', '/hqdefault.jpg'));
      add(withoutLive.replaceAll('/sddefault.jpg', '/mqdefault.jpg'));
      add(withoutLive.replaceAll('/sddefault.jpg', '/default.jpg'));
      add(withoutLive.replaceAll('/hqdefault.jpg', '/mqdefault.jpg'));
      add(withoutLive.replaceAll('/hqdefault.jpg', '/default.jpg'));
      add(withoutLive.replaceAll('/mqdefault.jpg', '/default.jpg'));
    }

    return candidates.toList();
  }

  static bool _isYouTubeThumbnail(String url) =>
      url.contains('ytimg.com/') || url.contains('img.youtube.com/');

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
