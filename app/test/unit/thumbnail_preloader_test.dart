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
    });

    test('normalizes live thumbnails before loading', () {
      final candidates = ThumbnailPreloader.candidateUrls(
        'https://i.ytimg.com/vi/abc123/hq_live.jpg',
      );

      expect(candidates.first, 'https://i.ytimg.com/vi/abc123/hq.jpg');
    });
  });
}
