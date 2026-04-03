import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/utils/thumbnail_preloader.dart';

void main() {
  group('ThumbnailPreloader.candidateUrls', () {
    test('adds stable fallbacks for youtube thumbnails', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        'https://i.ytimg.com/vi/abc123/maxresdefault.jpg',
      );

      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123/hqdefault.jpg'),
      );
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123/mqdefault.jpg'),
      );
      expect(candidates, contains('https://i.ytimg.com/vi/abc123/default.jpg'));
    });

    test('rewrites broken live thumbnail variants to valid youtube urls', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        '//i.ytimg.com/vi/abc123/hq_live.jpg',
      );

      expect(
        candidates.first,
        'https://i.ytimg.com/vi/abc123/hqdefault_live.jpg',
      );
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123/hqdefault.jpg'),
      );
      expect(
        candidates,
        isNot(contains('https://i.ytimg.com/vi/abc123/hq.jpg')),
      );
    });

    test('keeps valid live thumbnail urls and adds non-live fallback', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        'https://i.ytimg.com/vi/abc123/hqdefault_live.jpg',
      );

      expect(
        candidates.first,
        'https://i.ytimg.com/vi/abc123/hqdefault_live.jpg',
      );
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123/hqdefault.jpg'),
      );
    });
  });
}
