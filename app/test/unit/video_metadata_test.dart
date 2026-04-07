import 'package:baby_monitor/data/models/video_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoMetadata', () {
    test('hydrates channel title from joined yt_channels row', () {
      final video = VideoMetadata.fromSupabaseRow({
        'video_id': 'abc123xyz89',
        'title': 'Alphabet Song',
        'channel_id': 'UC123',
        'yt_channels': {'title': 'Songs for Kids'},
      });

      expect(video.channelId, 'UC123');
      expect(video.channelTitle, 'Songs for Kids');
    });

    test('detects shorts from duration or shorts hashtag', () {
      const shortByDuration = VideoMetadata(
        videoId: 'abc123xyz89',
        title: 'Counting with Blocks',
        durationSeconds: 45,
      );
      const shortByTitle = VideoMetadata(
        videoId: 'xyz123abc89',
        title: 'Animal Facts #Shorts',
        durationSeconds: 120,
      );
      const regularVideo = VideoMetadata(
        videoId: 'lmn123opq89',
        title: 'Full Episode',
        durationSeconds: 600,
      );

      expect(shortByDuration.detectedAsShort, isTrue);
      expect(shortByTitle.detectedAsShort, isTrue);
      expect(regularVideo.detectedAsShort, isFalse);
    });

    test(
      'durationSeconds=0 without shorts marker is not detected as short',
      () {
        const video = VideoMetadata(
          videoId: 'abc123xyz89',
          title: 'Some Video',
          durationSeconds: 0,
        );
        expect(video.detectedAsShort, isFalse);
      },
    );

    test('durationSeconds=0 with #shorts in title is detected as short', () {
      const video = VideoMetadata(
        videoId: 'abc123xyz89',
        title: 'Fun Facts #Shorts',
        durationSeconds: 0,
      );
      expect(video.detectedAsShort, isTrue);
    });

    test('durationSeconds=0 with isShort=true is detected as short', () {
      const video = VideoMetadata(
        videoId: 'abc123xyz89',
        title: 'Fun Video',
        durationSeconds: 0,
        isShort: true,
      );
      expect(video.detectedAsShort, isTrue);
    });

    test('boundary: 60s is short, 61s is not', () {
      const at60 = VideoMetadata(
        videoId: 'abc123xyz89',
        title: 'Quick Clip',
        durationSeconds: 60,
      );
      const at61 = VideoMetadata(
        videoId: 'def456uvw12',
        title: 'Slightly Longer',
        durationSeconds: 61,
      );
      expect(at60.detectedAsShort, isTrue);
      expect(at61.detectedAsShort, isFalse);
    });
  });
}
