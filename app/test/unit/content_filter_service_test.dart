import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/content_filter_service.dart';
import 'package:baby_monitor/data/repositories/profile_repository.dart';
import 'package:baby_monitor/data/repositories/video_repository.dart';

void main() {
  late ContentFilterService service;

  setUp(() {
    service = ContentFilterService();
  });

  group('ContentFilterService', () {
    test('approves video within age range and below thresholds', () {
      final analysis = VideoAnalysis(
        videoId: 'test1',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 8,
        overstimulationScore: 3.0,
        educationalScore: 7.0,
        scarinessScore: 2.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 1.0,
        audioSafetyScore: 9.0,
        contentLabels: ['educational'],
        detectedIssues: [],
        analysisReasoning: 'Safe content',
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

      final result = service.filterForChild(analysis: analysis, child: child);
      expect(result.isApproved, isTrue);
    });

    test('rejects globally blacklisted video', () {
      final analysis = VideoAnalysis(
        videoId: 'blacklisted',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 12,
        overstimulationScore: 1.0,
        educationalScore: 8.0,
        scarinessScore: 1.0,
        brainrotScore: 1.0,
        languageSafetyScore: 10.0,
        violenceScore: 1.0,
        audioSafetyScore: 10.0,
        contentLabels: [],
        detectedIssues: [],
        analysisReasoning: '',
        confidence: 0.95,
        isGloballyBlacklisted: true,
      );

      final child = ChildProfile(
        id: 'child1',
        parentId: 'parent1',
        name: 'Test Kid',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)),
        filterSensitivity: {},
      );

      final result = service.filterForChild(analysis: analysis, child: child);
      expect(result.isApproved, isFalse);
    });

    test('rejects video with high scariness for sensitive child', () {
      final analysis = VideoAnalysis(
        videoId: 'scary',
        ageMinAppropriate: 3,
        ageMaxAppropriate: 12,
        overstimulationScore: 3.0,
        educationalScore: 5.0,
        scarinessScore: 8.0,
        brainrotScore: 2.0,
        languageSafetyScore: 9.0,
        violenceScore: 2.0,
        audioSafetyScore: 9.0,
        contentLabels: ['cartoon'],
        detectedIssues: ['dark_themes'],
        analysisReasoning: 'Contains scary elements',
        confidence: 0.88,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'child1',
        parentId: 'parent1',
        name: 'Test Kid',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 4)),
        filterSensitivity: {
          'scariness': 9, // Very sensitive to scary content
        },
      );

      final result = service.filterForChild(analysis: analysis, child: child);
      expect(result.isApproved, isFalse);
    });

    test('marks low confidence as pending', () {
      final analysis = VideoAnalysis(
        videoId: 'unsure',
        ageMinAppropriate: 0,
        ageMaxAppropriate: 18,
        overstimulationScore: 5.0,
        educationalScore: 5.0,
        scarinessScore: 5.0,
        brainrotScore: 5.0,
        languageSafetyScore: 5.0,
        violenceScore: 5.0,
        audioSafetyScore: 5.0,
        contentLabels: [],
        detectedIssues: [],
        analysisReasoning: '',
        confidence: 0.3,
        isGloballyBlacklisted: false,
      );

      final child = ChildProfile(
        id: 'child1',
        parentId: 'parent1',
        name: 'Test Kid',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 6)),
        filterSensitivity: {},
      );

      final result = service.filterForChild(analysis: analysis, child: child);
      // Low confidence should not be auto-approved
      expect(result.isApproved, isFalse);
    });
  });
}
