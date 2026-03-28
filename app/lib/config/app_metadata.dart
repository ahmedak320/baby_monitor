/// App store metadata and legal document URLs.
class AppMetadata {
  AppMetadata._();

  static const String appName = 'Baby Monitor';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String bundleId = 'com.babymonitor.app';

  static const String shortDescription =
      'Safe YouTube content filtering for kids';
  static const String fullDescription =
      'Baby Monitor gives parents complete control over what YouTube '
      'content their children can watch. Our AI analyzes every video — '
      'not just titles and thumbnails, but the actual content — to ensure '
      'it is age-appropriate, non-overstimulating, and free of '
      'inappropriate material.\n\n'
      'Features:\n'
      '• AI-powered content analysis (text, visual, and audio)\n'
      '• Age-adaptive filtering (toddler through 12+)\n'
      '• Screen time management with daily limits and bedtime\n'
      '• Parental dashboard with activity reports\n'
      '• Community-shared analysis (analyzed once, safe for all)\n'
      '• Kid-safe player with no ads and no YouTube recommendations\n'
      '• Multiple child profiles with individual settings\n'
      '• Content scheduling (premium)\n'
      '• Offline playlists (premium)';

  static const List<String> keywords = [
    'parental controls',
    'kids youtube',
    'safe youtube',
    'content filter',
    'screen time',
    'child safety',
    'youtube for kids',
    'brainrot filter',
    'kid safe videos',
  ];

  static const String privacyPolicyUrl = 'https://babymonitor.app/privacy';
  static const String termsOfServiceUrl = 'https://babymonitor.app/terms';
  static const String supportEmail = 'support@babymonitor.app';

  static const String ageRating = '4+'; // App is for parents, not children
  static const String category = 'Parenting';
  static const String contentRating = 'Everyone';
}
