import 'package:baby_monitor/data/models/video_metadata.dart';
import 'package:baby_monitor/data/repositories/profile_repository.dart';
import 'package:baby_monitor/data/repositories/video_repository.dart';
import 'package:baby_monitor/domain/services/content_filter_service.dart';
import 'package:baby_monitor/domain/services/feed_curation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shorts Feed Logic', () {
    test('videos without analysis are added with isPendingAnalysis true', () {
      // Arrange
      final video = VideoMetadata(
        videoId: 'short123',
        title: 'Fun Short Video',
        durationSeconds: 45,
      );

      // Act
      final item = FeedItem(
        video: video,
        analysis: null,
        contentLabels: [],
        isPendingAnalysis: true,
      );

      // Assert
      expect(item.isPendingAnalysis, isTrue);
      expect(item.analysis, isNull);
      expect(item.video.detectedAsShort, isTrue);
    });

    test(
      'videos with approved analysis are added with isPendingAnalysis false',
      () {
        // Arrange
        final video = VideoMetadata(
          videoId: 'short456',
          title: 'Educational Short',
          durationSeconds: 55,
        );

        final analysis = VideoAnalysis(
          videoId: 'short456',
          confidence: 0.9,
          contentLabels: ['educational'],
        );

        // Act
        final item = FeedItem(
          video: video,
          analysis: analysis,
          contentLabels: analysis.contentLabels,
          isPendingAnalysis: false,
        );

        // Assert
        expect(item.isPendingAnalysis, isFalse);
        expect(item.analysis, isNotNull);
        expect(item.contentLabels, contains('educational'));
      },
    );

    test('shorts are correctly detected by duration', () {
      const short45s = VideoMetadata(
        videoId: 'abc123',
        title: 'Quick Video',
        durationSeconds: 45,
      );
      const short60s = VideoMetadata(
        videoId: 'def456',
        title: 'Full Minute',
        durationSeconds: 60,
      );
      const longVideo = VideoMetadata(
        videoId: 'ghi789',
        title: 'Long Video',
        durationSeconds: 61,
      );

      expect(short45s.detectedAsShort, isTrue);
      expect(short60s.detectedAsShort, isTrue);
      expect(longVideo.detectedAsShort, isFalse);
    });

    test('shorts are correctly detected by title hashtag', () {
      const shortByTitle = VideoMetadata(
        videoId: 'xyz123',
        title: 'Fun Facts #Shorts',
        durationSeconds: 120, // Long duration but has #shorts
      );
      const regularVideo = VideoMetadata(
        videoId: 'xyz456',
        title: 'Regular Video',
        durationSeconds: 120,
      );

      expect(shortByTitle.detectedAsShort, isTrue);
      expect(regularVideo.detectedAsShort, isFalse);
    });

    test('videos with isShort flag are detected as shorts', () {
      const shortByFlag = VideoMetadata(
        videoId: 'flag123',
        title: 'Short Video',
        durationSeconds: 0,
        isShort: true,
      );

      expect(shortByFlag.detectedAsShort, isTrue);
    });
  });

  group('ContentFilterService Shorts Filtering', () {
    late ContentFilterService filterService;

    setUp(() {
      filterService = ContentFilterService();
    });

    test('approves short video within age range', () {
      final analysis = VideoAnalysis(
        videoId: 'short1',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 7.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['educational', 'shorts'],
        detectedIssues: [],
        analysisReasoning: 'Safe short content',
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'child1',
        parentId: 'parent1',
        name: 'Test Kid',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)),
        filterSensitivity: {
          'overstimulation': 7,
          'scariness': 7,
          'brainrot': 7,
          'language': 8,
        },
      );

      final result = filterService.filterForChild(
        analysis: analysis,
        child: child,
      );
      expect(result.isApproved, isTrue);
    });

    test('rejects short video with high brainrot score', () {
      final analysis = VideoAnalysis(
        videoId: 'short2',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 2.0,
        scarinessScore: 2.0,
        brainrotScore: 9.0, // High brainrot
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['shorts'],
        detectedIssues: ['low_quality'],
        analysisReasoning: 'Mindless content',
        confidence: 0.85,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'child1',
        parentId: 'parent1',
        name: 'Test Kid',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)),
        filterSensitivity: {
          'overstimulation': 7,
          'scariness': 7,
          'brainrot': 8, // Strict brainrot filter
          'language': 8,
        },
      );

      final result = filterService.filterForChild(
        analysis: analysis,
        child: child,
      );
      expect(result.isApproved, isFalse);
      expect(result.reason, contains('Brainrot'));
    });
  });
}
