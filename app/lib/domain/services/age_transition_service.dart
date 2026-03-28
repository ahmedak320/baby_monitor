import '../../data/datasources/local/preferences_cache.dart';
import '../../data/repositories/profile_repository.dart';
import 'age_recommendation_service.dart';

/// Represents an age bracket transition for a child.
class AgeTransition {
  final ChildProfile child;
  final int newAge;
  final AgeBracketConfig previousBracket;
  final AgeBracketConfig newBracket;

  const AgeTransition({
    required this.child,
    required this.newAge,
    required this.previousBracket,
    required this.newBracket,
  });

  /// Human-readable description of the transition.
  String get message =>
      '${child.name} is now $newAge! Content recommendations have been '
      'updated from ${previousBracket.label} to ${newBracket.label}.';

  /// Suggested new filter sensitivity values.
  Map<String, double> get suggestedSensitivity => newBracket.defaultSensitivity;
}

/// Service that detects when children cross age bracket boundaries
/// and suggests updated filter settings.
class AgeTransitionService {
  AgeTransitionService._();

  /// Check all children for age bracket transitions since last check.
  /// Returns a list of transitions that occurred.
  static Future<List<AgeTransition>> checkTransitions(
    List<ChildProfile> children,
  ) async {
    final transitions = <AgeTransition>[];

    for (final child in children) {
      final storedBracket = PreferencesCache.getChildBracket(child.id);
      final currentBracket = AgeRecommendationService.getConfigForDob(
        child.dateOfBirth,
      );

      if (storedBracket != null && storedBracket != currentBracket.label) {
        // Find the previous bracket config for context
        final previousConfig = AgeRecommendationService.getConfigForAge(
          _ageForBracketLabel(storedBracket),
        );

        final now = DateTime.now();
        int age = now.year - child.dateOfBirth.year;
        if (now.month < child.dateOfBirth.month ||
            (now.month == child.dateOfBirth.month &&
                now.day < child.dateOfBirth.day)) {
          age--;
        }

        transitions.add(
          AgeTransition(
            child: child,
            newAge: age,
            previousBracket: previousConfig,
            newBracket: currentBracket,
          ),
        );
      }

      // Store current bracket for next check
      await PreferencesCache.setChildBracket(child.id, currentBracket.label);
    }

    return transitions;
  }

  /// Apply suggested sensitivity settings for a transition.
  static Future<void> applyTransitionSettings(
    AgeTransition transition,
    ProfileRepository profileRepo,
  ) async {
    final newSensitivity = Map<String, dynamic>.from(
      transition.child.filterSensitivity,
    );

    // Update with new bracket defaults
    for (final entry in transition.suggestedSensitivity.entries) {
      newSensitivity[entry.key] = entry.value;
    }

    // Also update max video duration
    newSensitivity['max_video_duration_minutes'] =
        transition.newBracket.maxVideoDurationMinutes;

    await profileRepo.updateChild(transition.child.id, {
      'filter_sensitivity': newSensitivity,
    });
  }

  /// Map bracket labels back to representative ages for lookup.
  static int _ageForBracketLabel(String label) {
    switch (label) {
      case 'Toddler':
        return 1;
      case 'Preschool':
        return 4;
      case 'Early School':
        return 6;
      case 'Older Kids':
        return 10;
      default:
        return 10;
    }
  }
}
