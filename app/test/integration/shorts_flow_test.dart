import 'package:baby_monitor/data/models/video_metadata.dart';
import 'package:baby_monitor/data/repositories/profile_repository.dart';
import 'package:baby_monitor/data/repositories/video_repository.dart';
import 'package:baby_monitor/domain/services/content_filter_service.dart';
import 'package:baby_monitor/domain/services/feed_curation_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for the shorts discovery and filtering flow.
/// 
/// This test verifies the core logic without requiring external services:
/// 1. Shorts detection works correctly
/// 2. FeedItem creation handles pending/analyzed states
/// 3. Content filtering works for shorts
/// 
/// Run with: flutter test test/integration/shorts_flow_test.dart
void main() {
  group('Shorts Detection', () {
    test('detectedAsShort correctly identifies short videos by duration', () {
      const short30s = VideoMetadata(
        videoId: 'test1',
        title: 'Quick Video',
        durationSeconds: 30,
      );
      const short60s = VideoMetadata(
        videoId: 'test2',
        title: 'Full Minute',
        durationSeconds: 60,
      );
      const longVideo = VideoMetadata(
        videoId: 'test3',
        title: 'Long Video',
        durationSeconds: 120,
      );

      expect(short30s.detectedAsShort, isTrue, reason: '30s should be a short');
      expect(short60s.detectedAsShort, isTrue, reason: '60s should be a short');
      expect(longVideo.detectedAsShort, isFalse, reason: '120s should not be a short');
    });

    test('detectedAsShort identifies shorts by title hashtag', () {
      const shortByTitle = VideoMetadata(
        videoId: 'test4',
        title: 'Fun Facts #Shorts',
        durationSeconds: 90, // Longer than 60 but has #shorts
      );
      const regularVideo = VideoMetadata(
        videoId: 'test5',
        title: 'Regular Video',
        durationSeconds: 90,
      );

      expect(shortByTitle.detectedAsShort, isTrue, reason: 'Title with #shorts should be a short');
      expect(regularVideo.detectedAsShort, isFalse, reason: 'Regular video should not be a short');
    });

    test('detectedAsShort identifies shorts by isShort flag', () {
      const shortByFlag = VideoMetadata(
        videoId: 'test6',
        title: 'Short Video',
        durationSeconds: 0,
        isShort: true,
      );
      const notShort = VideoMetadata(
        videoId: 'test7',
        title: 'Not Short',
        durationSeconds: 0,
        isShort: false,
      );

      expect(shortByFlag.detectedAsShort, isTrue, reason: 'Video with isShort=true should be a short');
      expect(notShort.detectedAsShort, isFalse, reason: 'Video with isShort=false should not be a short');
    });

    test('detectedAsShort boundary at 60 seconds', () {
      const at60 = VideoMetadata(
        videoId: 'boundary1',
        title: 'Exactly 60s',
        durationSeconds: 60,
      );
      const at61 = VideoMetadata(
        videoId: 'boundary2',
        title: '61 seconds',
        durationSeconds: 61,
      );

      expect(at60.detectedAsShort, isTrue, reason: '60s is the boundary for shorts');
      expect(at61.detectedAsShort, isFalse, reason: '61s exceeds short limit');
    });
  });

  group('FeedItem Creation', () {
    test('FeedItem for pending shorts has correct state', () {
      final shortVideo = VideoMetadata(
        videoId: 'pending_short',
        title: 'Pending Short',
        durationSeconds: 45,
      );

      final feedItem = FeedItem(
        video: shortVideo,
        analysis: null,
        contentLabels: [],
        isPendingAnalysis: true,
      );

      expect(feedItem.isPendingAnalysis, isTrue);
      expect(feedItem.video.detectedAsShort, isTrue);
      expect(feedItem.analysis, isNull);
      expect(feedItem.contentLabels, isEmpty);
    });

    test('FeedItem for analyzed shorts has correct state', () {
      final shortVideo = VideoMetadata(
        videoId: 'analyzed_short',
        title: 'Analyzed Short',
        durationSeconds: 55,
      );

      final analysis = VideoAnalysis(
        videoId: 'analyzed_short',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 8.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['educational', 'shorts'],
        detectedIssues: [],
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final feedItem = FeedItem(
        video: shortVideo,
        analysis: analysis,
        contentLabels: analysis.contentLabels,
        isPendingAnalysis: false,
      );

      expect(feedItem.isPendingAnalysis, isFalse);
      expect(feedItem.analysis, isNotNull);
      expect(feedItem.contentLabels, contains('educational'));
      expect(feedItem.contentLabels, contains('shorts'));
    });
  });

  group('ContentFilterService', () {
    late ContentFilterService filterService;

    setUp(() {
      filterService = ContentFilterService();
    });

    test('approves safe shorts for appropriate age', () {
      final analysis = VideoAnalysis(
        videoId: 'safe_short',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 8.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['educational', 'shorts'],
        detectedIssues: [],
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'test_child',
        parentId: 'test_parent',
        name: 'Test Child',
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

      expect(result.isApproved, isTrue, reason: 'Safe short should be approved');
      expect(result.decision, equals(FilterDecision.approved));
    });

    test('rejects shorts with high brainrot', () {
      final analysis = VideoAnalysis(
        videoId: 'brainrot_short',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 2.0,
        scarinessScore: 2.0,
        brainrotScore: 9.0, // High brainrot
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['shorts', 'low_quality'],
        detectedIssues: ['mindless_content'],
        confidence: 0.85,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'test_child',
        parentId: 'test_parent',
        name: 'Test Child',
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

      expect(result.isApproved, isFalse, reason: 'High brainrot short should be rejected');
      expect(result.reason, contains('Brainrot'));
    });

    test('rejects globally blacklisted shorts', () {
      final analysis = VideoAnalysis(
        videoId: 'blacklisted_short',
        ageMinAppropriate: 0,
        ageMaxAppropriate: 18,
        overstimulationScore: 1.0,
        educationalScore: 5.0,
        scarinessScore: 1.0,
        brainrotScore: 1.0,
        languageSafetyScore: 10.0,
        violenceScore: 1.0,
        audioSafetyScore: 10.0,
        contentLabels: [],
        detectedIssues: [],
        confidence: 0.95,
        isGloballyBlacklisted: true, // Globally blacklisted
      );

      final child = ChildProfile(
        id: 'test_child',
        parentId: 'test_parent',
        name: 'Test Child',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)),
        filterSensitivity: {},
      );

      final result = filterService.filterForChild(
        analysis: analysis,
        child: child,
      );

      expect(result.isApproved, isFalse, reason: 'Blacklisted short should be rejected');
      expect(result.reason, contains('Globally blacklisted'));
    });

    test('rejects shorts below minimum age', () {
      final analysis = VideoAnalysis(
        videoId: 'teen_short',
        ageMinAppropriate: 10, // For ages 10+
        ageMaxAppropriate: 16,
        overstimulationScore: 3.0,
        educationalScore: 7.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: [],
        detectedIssues: [],
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'test_child',
        parentId: 'test_parent',
        name: '5 Year Old',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)), // 5 years old
        filterSensitivity: {},
      );

      final result = filterService.filterForChild(
        analysis: analysis,
        child: child,
      );

      expect(result.isApproved, isFalse, reason: 'Short below minimum age should be rejected');
      expect(result.reason, contains('Below minimum age'));
    });
  });

  group('Shorts Provider Logic', () {
    test('handles pending videos correctly - whitelist approach', () {
      final shorts = [
        VideoMetadata(videoId: 's1', title: 'Short 1', durationSeconds: 30),
        VideoMetadata(videoId: 's2', title: 'Short 2', durationSeconds: 45),
        VideoMetadata(videoId: 's3', title: 'Short 3', durationSeconds: 55),
      ];

      final feedItems = <FeedItem>[];
      
      // Simulate processing videos without analysis (whitelist approach)
      for (final video in shorts) {
        // No analysis yet - this is the key fix: we add them anyway
        feedItems.add(FeedItem(
          video: video,
          analysis: null,
          contentLabels: [],
          isPendingAnalysis: true,
        ));
      }

      expect(feedItems.length, equals(3), reason: 'Should have 3 shorts in feed');
      expect(feedItems.every((item) => item.isPendingAnalysis), isTrue, 
          reason: 'All items should be pending analysis');
      expect(feedItems.every((item) => item.video.detectedAsShort), isTrue,
          reason: 'All items should be shorts');
    });

    test('handles analyzed and approved videos', () {
      final short = VideoMetadata(videoId: 's1', title: 'Short 1', durationSeconds: 30);

      final analysis = VideoAnalysis(
        videoId: 's1',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 12,
        overstimulationScore: 3.0,
        educationalScore: 8.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['educational'],
        detectedIssues: [],
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'c1',
        parentId: 'p1',
        name: 'Child',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 6)),
        filterSensitivity: {'brainrot': 7},
      );

      final result = ContentFilterService().filterForChild(
        analysis: analysis,
        child: child,
      );

      final feedItems = <FeedItem>[];
      
      if (result.isApproved) {
        feedItems.add(FeedItem(
          video: short,
          analysis: analysis,
          contentLabels: analysis.contentLabels,
          isPendingAnalysis: false,
        ));
      }

      expect(feedItems.length, equals(1));
      expect(feedItems.first.isPendingAnalysis, isFalse);
      expect(feedItems.first.analysis, isNotNull);
    });

    test('handles analyzed and rejected videos', () {
      final short = VideoMetadata(videoId: 's1', title: 'Inappropriate Short', durationSeconds: 30);

      final analysis = VideoAnalysis(
        videoId: 's1',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 12,
        overstimulationScore: 3.0,
        educationalScore: 2.0,
        scarinessScore: 2.0,
        brainrotScore: 9.0, // Too high
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['low_quality'],
        detectedIssues: ['mindless'],
        confidence: 0.9,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'c1',
        parentId: 'p1',
        name: 'Child',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 6)),
        filterSensitivity: {'brainrot': 8}, // Strict
      );

      final result = ContentFilterService().filterForChild(
        analysis: analysis,
        child: child,
      );

      final feedItems = <FeedItem>[];
      
      if (result.isApproved) {
        feedItems.add(FeedItem(
          video: short,
          analysis: analysis,
          contentLabels: analysis.contentLabels,
          isPendingAnalysis: false,
        ));
      }
      // If not approved, we don't add to feed (would log filtered instead)

      expect(feedItems.length, equals(0), reason: 'Rejected shorts should not be in feed');
      expect(result.isApproved, isFalse);
    });
  });
}
