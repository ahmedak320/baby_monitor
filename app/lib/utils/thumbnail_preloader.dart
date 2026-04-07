import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../data/models/video_metadata.dart';

/// Utility to preload thumbnail images for smoother feed scrolling.
class ThumbnailPreloader {
  ThumbnailPreloader._();

  static final _pipedProxyPattern = RegExp(
    r'https?://[^/]*pipedproxy[^/]*/vi/([a-zA-Z0-9_-]{11})/([^?]+)',
  );

  static String normalizeUrl(String thumbnailUrl) {
    final trimmed = thumbnailUrl.trim();
    if (trimmed.isEmpty) return '';

    var normalized = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;

    // Convert Piped proxy URLs to direct YouTube thumbnail URLs.
    final pipedMatch = _pipedProxyPattern.firstMatch(normalized);
    if (pipedMatch != null) {
      final videoId = pipedMatch.group(1)!;
      final filename = pipedMatch.group(2)!;
      normalized = 'https://i.ytimg.com/vi/$videoId/$filename';
    }

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

    // Ensure direct YouTube fallbacks exist for any URL containing a video ID.
    final videoIdMatch = RegExp(
      r'/vi/([a-zA-Z0-9_-]{11})/',
    ).firstMatch(normalized);
    if (videoIdMatch != null) {
      final videoId = videoIdMatch.group(1)!;
      add('https://i.ytimg.com/vi/$videoId/hqdefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/mqdefault.jpg');
      add('https://i.ytimg.com/vi/$videoId/default.jpg');
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
