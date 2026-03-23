/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Baby Monitor';

  // Age brackets for content filtering
  static const int toddlerMinAge = 1;
  static const int toddlerMaxAge = 3;
  static const int preschoolMinAge = 3;
  static const int preschoolMaxAge = 5;
  static const int earlySchoolMinAge = 5;
  static const int earlySchoolMaxAge = 8;
  static const int olderKidsMinAge = 8;
  static const int olderKidsMaxAge = 12;

  // Freemium limits
  static const int freeMonthlyAnalysisLimit = 50;
  static const int freeMaxChildProfiles = 1;

  // Screen time defaults
  static const int defaultBreakIntervalMinutes = 30;
  static const int defaultBreakDurationMinutes = 5;
  static const int defaultWinddownWarningMinutes = 5;

  // Content types
  static const List<String> contentTypes = [
    'educational',
    'nature',
    'cartoons',
    'music',
    'storytime',
    'fun',
    'soothing',
    'creative',
  ];
}
