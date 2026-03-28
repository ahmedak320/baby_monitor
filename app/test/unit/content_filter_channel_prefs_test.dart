import 'package:flutter_test/flutter_test.dart';
import 'package:baby_monitor/domain/services/content_filter_service.dart';
import 'package:baby_monitor/data/repositories/profile_repository.dart';
import 'package:baby_monitor/data/repositories/video_repository.dart';

void main() {
  late ContentFilterService service;

  setUp(() {
    service = ContentFilterService();
  });

  group('ContentFilterService channel preferences', () {
    final safeAnalysis = VideoAnalysis(
      videoId: 'vid1',
      ageMinAppropriate: 3,
      ageMaxAppropriate: 12,
      overstimulationScore: 3.0,
      educationalScore: 7.0,
      scarinessScore: 2.0,
      brainrotScore: 2.0,
      languageSafetyScore: 9.0,
      violenceScore: 1.0,
      audioSafetyScore: 9.0,
      contentLabels: [],
      detectedIssues: [],
      analysisReasoning: '',
      confidence: 0.9,
      isGloballyBlacklisted: false,
    );

    final child = ChildProfile(
      id: 'child1',
      parentId: 'parent1',
      name: 'Test Kid',
      dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)),
      filterSensitivity: {},
    );

    test('approves video from approved channel', () {
      final result = service.filterForChild(
        analysis: safeAnalysis,
        child: child,
        channelId: 'UC_approved',
        channelPrefs: {'UC_approved': 'approved'},
      );

      expect(result.isApproved, isTrue);
      expect(result.reason, 'Channel approved by parent');
      expect(result.confidenceScore, 1.0);
    });

    test('rejects video from blocked channel', () {
      final result = service.filterForChild(
        analysis: safeAnalysis,
        child: child,
        channelId: 'UC_blocked',
        channelPrefs: {'UC_blocked': 'blocked'},
      );

      expect(result.isApproved, isFalse);
      expect(result.reason, 'Channel blocked by parent');
    });

    test('channel prefs do not apply when channelId is null', () {
      final result = service.filterForChild(
        analysis: safeAnalysis,
        child: child,
        channelId: null,
        channelPrefs: {'UC_blocked': 'blocked'},
      );

      // Should fall through to normal filtering
      expect(result.isApproved, isTrue);
      expect(result.reason, isNot('Channel blocked by parent'));
    });

    test('channel prefs do not apply for unknown channel', () {
      final result = service.filterForChild(
        analysis: safeAnalysis,
        child: child,
        channelId: 'UC_unknown',
        channelPrefs: {'UC_other': 'blocked'},
      );

      expect(result.isApproved, isTrue);
    });

    test('video overrides take precedence over channel prefs', () {
      final result = service.filterForChild(
        analysis: safeAnalysis,
        child: child,
        channelId: 'UC_blocked',
        channelPrefs: {'UC_blocked': 'blocked'},
        videoOverrides: {'vid1': 'approved'},
      );

      // Video override wins
      expect(result.isApproved, isTrue);
      expect(result.reason, 'Parent approved override');
    });
  });
}
