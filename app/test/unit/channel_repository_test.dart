import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/data/models/video_metadata.dart';
import 'package:baby_monitor/data/datasources/remote/piped_api_client.dart';

void main() {
  group('ChannelMetadata', () {
    test('fromSupabaseRow parses all fields correctly', () {
      final row = {
        'channel_id': 'UC123',
        'title': 'Test Channel',
        'description': 'A test channel',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'subscriber_count': 1500000,
        'is_kids_channel': true,
      };

      final channel = ChannelMetadata.fromSupabaseRow(row);

      expect(channel.channelId, 'UC123');
      expect(channel.title, 'Test Channel');
      expect(channel.description, 'A test channel');
      expect(channel.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(channel.subscriberCount, 1500000);
      expect(channel.isKidsChannel, isTrue);
    });

    test('fromSupabaseRow handles null fields with defaults', () {
      final row = {
        'channel_id': 'UC456',
        'title': null,
        'description': null,
        'thumbnail_url': null,
        'subscriber_count': null,
        'is_kids_channel': null,
      };

      final channel = ChannelMetadata.fromSupabaseRow(row);

      expect(channel.channelId, 'UC456');
      expect(channel.title, '');
      expect(channel.description, '');
      expect(channel.thumbnailUrl, '');
      expect(channel.subscriberCount, 0);
      expect(channel.isKidsChannel, isFalse);
    });

    test('toSupabaseRow roundtrips correctly', () {
      const channel = ChannelMetadata(
        channelId: 'UCxyz',
        title: 'My Channel',
        description: 'Desc',
        thumbnailUrl: 'https://img.com/a.png',
        subscriberCount: 42000,
        isKidsChannel: true,
      );

      final row = channel.toSupabaseRow();
      final restored = ChannelMetadata.fromSupabaseRow(row);

      expect(restored.channelId, channel.channelId);
      expect(restored.title, channel.title);
      expect(restored.description, channel.description);
      expect(restored.thumbnailUrl, channel.thumbnailUrl);
      expect(restored.subscriberCount, channel.subscriberCount);
      expect(restored.isKidsChannel, channel.isKidsChannel);
    });
  });

  group('PipedApiClient channel search', () {
    test('searchChannels method exists and accepts a query', () {
      // Verify the method signature exists (compile-time check)
      final client = PipedApiClient();
      expect(client.searchChannels, isA<Function>());
    });
  });
}
