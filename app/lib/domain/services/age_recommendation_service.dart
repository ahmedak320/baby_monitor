import '../../config/constants.dart';

/// Age bracket with associated content and filter recommendations.
class AgeBracketConfig {
  final String label;
  final int minAge;
  final int maxAge;
  final Map<String, double> defaultSensitivity;
  final List<String> recommendedContentTypes;
  final List<String> suggestedSearchTerms;
  final int maxVideoDurationMinutes;

  const AgeBracketConfig({
    required this.label,
    required this.minAge,
    required this.maxAge,
    required this.defaultSensitivity,
    required this.recommendedContentTypes,
    required this.suggestedSearchTerms,
    required this.maxVideoDurationMinutes,
  });
}

/// Service that provides age-appropriate recommendations based on DOB.
class AgeRecommendationService {
  AgeRecommendationService._();

  static const _brackets = [
    AgeBracketConfig(
      label: 'Toddler',
      minAge: 0,
      maxAge: 2,
      defaultSensitivity: {
        'overstimulation': 9.0,
        'scariness': 9.0,
        'brainrot_tolerance': 8.0,
        'language_strictness': 9.0,
        'educational_preference': 6.0,
      },
      recommendedContentTypes: ['music', 'soothing', 'educational'],
      suggestedSearchTerms: [
        'nursery rhymes',
        'baby sensory',
        'lullabies',
        'shapes and colors',
      ],
      maxVideoDurationMinutes: 15,
    ),
    AgeBracketConfig(
      label: 'Preschool',
      minAge: 3,
      maxAge: 5,
      defaultSensitivity: {
        'overstimulation': 7.0,
        'scariness': 7.0,
        'brainrot_tolerance': 7.0,
        'language_strictness': 9.0,
        'educational_preference': 6.0,
      },
      recommendedContentTypes: [
        'educational',
        'cartoons',
        'music',
        'nature',
        'storytime',
      ],
      suggestedSearchTerms: [
        'peppa pig',
        'bluey',
        'numberblocks',
        'sesame street',
        'animals for kids',
      ],
      maxVideoDurationMinutes: 25,
    ),
    AgeBracketConfig(
      label: 'Early School',
      minAge: 5,
      maxAge: 8,
      defaultSensitivity: {
        'overstimulation': 5.0,
        'scariness': 5.0,
        'brainrot_tolerance': 6.0,
        'language_strictness': 8.0,
        'educational_preference': 5.0,
      },
      recommendedContentTypes: [
        'educational',
        'cartoons',
        'nature',
        'creative',
        'fun',
        'music',
      ],
      suggestedSearchTerms: [
        'science for kids',
        'art for kids',
        'wild kratts',
        'national geographic kids',
        'craft ideas kids',
      ],
      maxVideoDurationMinutes: 30,
    ),
    AgeBracketConfig(
      label: 'Older Kids',
      minAge: 8,
      maxAge: 12,
      defaultSensitivity: {
        'overstimulation': 4.0,
        'scariness': 4.0,
        'brainrot_tolerance': 5.0,
        'language_strictness': 7.0,
        'educational_preference': 4.0,
      },
      recommendedContentTypes: AppConstants.contentTypes, // all types
      suggestedSearchTerms: [
        'mark rober',
        'science experiments',
        'history for kids',
        'space documentary',
        'coding for kids',
      ],
      maxVideoDurationMinutes: 45,
    ),
  ];

  /// Get the age bracket config for a given age.
  static AgeBracketConfig getConfigForAge(int age) {
    for (final bracket in _brackets) {
      if (age >= bracket.minAge && age <= bracket.maxAge) {
        return bracket;
      }
    }
    // Default to oldest bracket
    return _brackets.last;
  }

  /// Get the age bracket config for a DOB.
  static AgeBracketConfig getConfigForDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return getConfigForAge(age);
  }

  /// Get default filter sensitivity for a given age.
  static Map<String, double> getDefaultSensitivity(int age) {
    return Map.from(getConfigForAge(age).defaultSensitivity);
  }

  /// Check if a child's age has crossed into a new bracket since last check.
  /// Returns the new bracket if changed, null otherwise.
  static AgeBracketConfig? checkBracketTransition(
    DateTime dob,
    String previousBracketLabel,
  ) {
    final current = getConfigForDob(dob);
    if (current.label != previousBracketLabel) {
      return current;
    }
    return null;
  }
}
