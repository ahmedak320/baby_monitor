class KidYoutubePlayerDiagnostics {
  const KidYoutubePlayerDiagnostics._();

  static bool shouldTreatWebResourceErrorAsFatal({
    required bool isForMainFrame,
    required String description,
  }) {
    if (!isForMainFrame) return false;

    final normalized = description.toLowerCase();
    return normalized.isEmpty ||
        normalized.contains('error') ||
        normalized.contains('not available') ||
        normalized.contains('connection') ||
        normalized.contains('refused');
  }

  static bool looksLikeConfigurationError(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('error 153') ||
        normalized.contains('error 152') ||
        normalized.contains('video player configuration error') ||
        normalized.contains('missing referer');
  }

  static bool looksLikeEmbedRestrictedError(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains(
          'playback on other websites has been disabled',
        ) ||
        normalized.contains('owner has restricted playback') ||
        normalized.contains('embedding disabled') ||
        normalized.contains('watch on youtube');
  }
}
