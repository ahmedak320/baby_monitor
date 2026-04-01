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
  });
}
