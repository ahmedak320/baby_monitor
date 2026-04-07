import 'package:baby_monitor/data/models/video_metadata.dart';
import 'package:baby_monitor/data/repositories/video_repository.dart';
import 'package:baby_monitor/domain/services/video_discovery_service.dart';
import 'package:baby_monitor/domain/services/youtube_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockYouTubeDataService extends Mock implements YouTubeDataService {}

class MockVideoRepository extends Mock implements VideoRepository {}

class FakeVideoMetadata extends Fake implements VideoMetadata {}

void main() {
  late MockYouTubeDataService mockYt;
  late MockVideoRepository mockRepo;
  late VideoDiscoveryService service;

  setUpAll(() {
    registerFallbackValue(FakeVideoMetadata());
  });

  setUp(() {
    mockYt = MockYouTubeDataService();
    mockRepo = MockVideoRepository();
    service = VideoDiscoveryService(ytService: mockYt, videoRepo: mockRepo);
  });

  group('discoverShorts', () {
    test(
      'enriches before filtering — videos with durationSeconds=0 are included after enrichment',
      () async {
        // Search returns videos WITHOUT duration (mimics YouTube Search API
        // which only returns snippet, not contentDetails).
        final searchResults = [
          const VideoMetadata(
            videoId: 'short1aaaaaa',
            title: 'Counting Fun',
            durationSeconds: 0,
          ),
          const VideoMetadata(
            videoId: 'long1bbbbbbb',
            title: 'Full Episode',
            durationSeconds: 0,
          ),
        ];

        when(
          () => mockYt.search(any(), maxResults: any(named: 'maxResults')),
        ).thenAnswer((_) async => VideoSearchResult(videos: searchResults));

        // Enrichment adds real durations (simulates getVideoDetailsBatch).
        when(() => mockYt.enrichCandidates(any())).thenAnswer((
          invocation,
        ) async {
          final candidates =
              invocation.positionalArguments[0] as List<VideoMetadata>;
          return candidates.map((c) {
            final duration = c.videoId == 'short1aaaaaa' ? 30 : 600;
            return VideoMetadata(
              videoId: c.videoId,
              title: c.title,
              durationSeconds: duration,
              channelId: 'UC_test_chan',
              channelTitle: 'Test Channel',
            );
          }).toList();
        });

        // Repository ingest is a no-op for tests.
        when(
          () => mockRepo.ingestDiscoveredVideo(
            any(),
            source: any(named: 'source'),
            analysisStatus: any(named: 'analysisStatus'),
            metadataGatePassed: any(named: 'metadataGatePassed'),
            metadataGateReason: any(named: 'metadataGateReason'),
            metadataGateConfidence: any(named: 'metadataGateConfidence'),
            metadataCheckedAt: any(named: 'metadataCheckedAt'),
            queuePriority: any(named: 'queuePriority'),
            queueSource: any(named: 'queueSource'),
          ),
        ).thenAnswer((_) async {});

        final result = await service.discoverShorts();

        // The short video (enriched duration=30s) should be included.
        expect(result.any((v) => v.videoId == 'short1aaaaaa'), isTrue);
        // The long video (enriched duration=600s) should be excluded.
        expect(result.any((v) => v.videoId == 'long1bbbbbbb'), isFalse);
        // enrichCandidates must have been called (verifies enrich-before-filter).
        verify(() => mockYt.enrichCandidates(any())).called(1);
      },
    );

    test('returns empty when all searches fail', () async {
      when(
        () => mockYt.search(any(), maxResults: any(named: 'maxResults')),
      ).thenThrow(Exception('network error'));

      final result = await service.discoverShorts();

      expect(result, isEmpty);
      verifyNever(() => mockYt.enrichCandidates(any()));
    });
  });
}
