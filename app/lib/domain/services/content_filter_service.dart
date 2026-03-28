import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../utils/age_calculator.dart';

/// Result of filtering a video for a specific child.
enum FilterDecision { approved, rejected, pending }

class FilterResult {
  final FilterDecision decision;
  final String reason;
  final double confidenceScore;

  const FilterResult({
    required this.decision,
    this.reason = '',
    this.confidenceScore = 0.0,
  });

  bool get isApproved => decision == FilterDecision.approved;
}

/// Core filtering service: maps analysis scores against per-child
/// filter sensitivity settings to produce approve/reject decisions.
class ContentFilterService {
  /// Filter a video for a specific child profile.
  ///
  /// Checks in order:
  /// 1. Parent video overrides (manual approve/block)
  /// 2. Parent channel preferences
  /// 3. Global blacklist
  /// 4. Age appropriateness
  /// 5. Score-based filtering against child's sensitivity settings
  FilterResult filterForChild({
    required VideoAnalysis analysis,
    required ChildProfile child,
    String? channelId,
    Map<String, String>? channelPrefs, // channelId -> 'approved'/'blocked'
    Map<String, String>? videoOverrides, // videoId -> 'approved'/'blocked'
  }) {
    // 1. Check video overrides
    if (videoOverrides != null) {
      final override = videoOverrides[analysis.videoId];
      if (override == 'approved') {
        return const FilterResult(
          decision: FilterDecision.approved,
          reason: 'Parent approved override',
          confidenceScore: 1.0,
        );
      }
      if (override == 'blocked') {
        return const FilterResult(
          decision: FilterDecision.rejected,
          reason: 'Parent blocked override',
          confidenceScore: 1.0,
        );
      }
    }

    // 2. Check channel preferences
    if (channelPrefs != null && channelId != null) {
      final channelPref = channelPrefs[channelId];
      if (channelPref == 'approved') {
        return const FilterResult(
          decision: FilterDecision.approved,
          reason: 'Channel approved by parent',
          confidenceScore: 1.0,
        );
      }
      if (channelPref == 'blocked') {
        return const FilterResult(
          decision: FilterDecision.rejected,
          reason: 'Channel blocked by parent',
          confidenceScore: 1.0,
        );
      }
    }

    // 3. Check global blacklist
    if (analysis.isGloballyBlacklisted) {
      return const FilterResult(
        decision: FilterDecision.rejected,
        reason: 'Globally blacklisted by community',
        confidenceScore: 1.0,
      );
    }

    // 3. Check age appropriateness
    final childAge = AgeCalculator.yearsFromDob(child.dateOfBirth);
    if (childAge < analysis.ageMinAppropriate) {
      return FilterResult(
        decision: FilterDecision.rejected,
        reason: 'Below minimum age (${analysis.ageMinAppropriate}+)',
        confidenceScore: 0.95,
      );
    }
    if (childAge > analysis.ageMaxAppropriate) {
      // Don't reject older kids, just note it
      // They might still enjoy younger content
    }

    // 4. Low confidence — treat as pending
    if (analysis.confidence < 0.5) {
      return const FilterResult(
        decision: FilterDecision.pending,
        reason: 'Analysis confidence too low',
        confidenceScore: 0.0,
      );
    }

    // 5. Score-based filtering
    final sensitivity = child.filterSensitivity;
    final issues = <String>[];

    // Get thresholds from child's sensitivity settings
    // Sensitivity is 1-10 where 10 = strictest
    // Scores are 1-10 where 10 = worst
    // A score exceeding (11 - sensitivity) triggers rejection

    // Threshold = 11 - sensitivity, clamped to minimum 3 so even
    // strictest settings still allow reasonably calm content
    final overstimThreshold = (11.0 - (sensitivity['overstimulation'] ?? 5.0))
        .clamp(3.0, 10.0);
    if (analysis.overstimulationScore > overstimThreshold) {
      issues.add(
        'Overstimulation: ${analysis.overstimulationScore.toStringAsFixed(1)} '
        '(max ${overstimThreshold.toStringAsFixed(1)})',
      );
    }

    final scarinessThreshold = (11.0 - (sensitivity['scariness'] ?? 3.0)).clamp(
      3.0,
      10.0,
    );
    if (analysis.scarinessScore > scarinessThreshold) {
      issues.add(
        'Scariness: ${analysis.scarinessScore.toStringAsFixed(1)} '
        '(max ${scarinessThreshold.toStringAsFixed(1)})',
      );
    }

    final brainrotThreshold =
        (11.0 -
                (sensitivity['brainrot_tolerance'] ??
                    sensitivity['brainrot'] ??
                    3.0))
            .clamp(3.0, 10.0);
    if (analysis.brainrotScore > brainrotThreshold) {
      issues.add(
        'Brainrot: ${analysis.brainrotScore.toStringAsFixed(1)} '
        '(max ${brainrotThreshold.toStringAsFixed(1)})',
      );
    }

    final languageThreshold =
        (11.0 - (sensitivity['language_strictness'] ?? 8.0)).clamp(2.0, 10.0);
    if (analysis.languageSafetyScore < languageThreshold) {
      issues.add(
        'Language safety: ${analysis.languageSafetyScore.toStringAsFixed(1)} '
        '(min ${languageThreshold.toStringAsFixed(1)})',
      );
    }

    // Violence is always strict for all kids
    if (analysis.violenceScore > 4.0) {
      issues.add('Violence: ${analysis.violenceScore.toStringAsFixed(1)}');
    }

    // Audio safety
    if (analysis.audioSafetyScore < 4.0) {
      issues.add(
        'Audio safety: ${analysis.audioSafetyScore.toStringAsFixed(1)}',
      );
    }

    if (issues.isNotEmpty) {
      return FilterResult(
        decision: FilterDecision.rejected,
        reason: issues.join('; '),
        confidenceScore: analysis.confidence,
      );
    }

    return FilterResult(
      decision: FilterDecision.approved,
      reason: 'Passed all filters',
      confidenceScore: analysis.confidence,
    );
  }

  /// Quick check if a video is likely suitable based on just age.
  bool isAgeAppropriate(int childAge, VideoAnalysis analysis) {
    return childAge >= analysis.ageMinAppropriate &&
        childAge <= analysis.ageMaxAppropriate + 2; // +2 buffer for older
  }
}
