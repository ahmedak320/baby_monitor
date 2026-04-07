import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/utils/thumbnail_preloader.dart';

void main() {
  group('ThumbnailPreloader.normalizeUrl', () {
    test('converts Piped proxy URL to direct YouTube URL', () {
      final result = ThumbnailPreloader.normalizeUrl(
        'https://pipedproxy.kavin.rocks/vi/abc123xyz89/hqdefault.jpg?host=i.ytimg.com',
      );
      expect(result, 'https://i.ytimg.com/vi/abc123xyz89/hqdefault.jpg');
    });

    test('passes regular YouTube URLs through unchanged', () {
      const url = 'https://i.ytimg.com/vi/abc123xyz89/maxresdefault.jpg';
      expect(ThumbnailPreloader.normalizeUrl(url), url);
    });

    test('returns empty string for empty or whitespace input', () {
      expect(ThumbnailPreloader.normalizeUrl(''), '');
      expect(ThumbnailPreloader.normalizeUrl('   '), '');
    });

    test('adds https to protocol-relative URLs', () {
      expect(
        ThumbnailPreloader.normalizeUrl(
          '//i.ytimg.com/vi/abc123xyz89/hqdefault.jpg',
        ),
        'https://i.ytimg.com/vi/abc123xyz89/hqdefault.jpg',
      );
    });
  });

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

    test('Piped proxy URL generates direct YouTube fallback candidates', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        'https://pipedproxy.kavin.rocks/vi/abc123xyz89/maxresdefault.jpg?host=i.ytimg.com',
      );

      // Normalized to direct YouTube URL
      expect(
        candidates.first,
        'https://i.ytimg.com/vi/abc123xyz89/maxresdefault.jpg',
      );
      // Contains quality fallbacks
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123xyz89/hqdefault.jpg'),
      );
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123xyz89/mqdefault.jpg'),
      );
      expect(
        candidates,
        contains('https://i.ytimg.com/vi/abc123xyz89/default.jpg'),
      );
    });

    test('non-YouTube URL returns single candidate', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        'https://example.com/thumb.jpg',
      );
      expect(candidates, hasLength(1));
      expect(candidates.first, 'https://example.com/thumb.jpg');
    });

    test('empty URL returns empty list', () {
      expect(ThumbnailPreloader.candidateUrls(''), isEmpty);
    });
  });
}
