/// Lightweight client-side heuristic filter for unanalyzed videos.
/// Decides if a video is likely safe enough to play immediately
/// while full AI analysis runs in the background.
class MetadataGateResult {
  final bool passed;
  final String reason;
  final double confidence;

  const MetadataGateResult({
    required this.passed,
    required this.reason,
    required this.confidence,
  });
}

class MetadataGateService {
  MetadataGateService._();

  /// Run the metadata gate on a video's metadata.
  /// No API calls — uses already-fetched data only.
  static MetadataGateResult check({
    required String title,
    required String channelTitle,
    required String description,
    required int durationSeconds,
    required List<String> tags,
    required int categoryId,
    bool isKidsChannel = false,
    bool madeForKids = false,
    double channelTrustScore = 0.0,
  }) {
    final titleLower = title.toLowerCase();
    final channelLower = channelTitle.toLowerCase();
    final descLower = description.toLowerCase();

    // 1. Title keyword blocklist — immediate reject
    for (final word in _titleBlocklist) {
      if (_containsBlockedTerm(titleLower, word)) {
        return MetadataGateResult(
          passed: false,
          reason: 'Title contains blocked term: $word',
          confidence: 0.9,
        );
      }
    }

    // 2. Description keyword blocklist
    for (final word in _descriptionBlocklist) {
      if (_containsBlockedTerm(descLower, word)) {
        return MetadataGateResult(
          passed: false,
          reason: 'Description contains blocked term: $word',
          confidence: 0.8,
        );
      }
    }

    // 3. Duration sanity — extremely long videos (>3 hours) suspicious
    if (durationSeconds > 10800) {
      return MetadataGateResult(
        passed: false,
        reason: 'Video too long (${durationSeconds ~/ 3600}h) for kids',
        confidence: 0.6,
      );
    }

    // 4. Trusted channel — high confidence pass
    if (madeForKids || isKidsChannel || channelTrustScore >= 0.8) {
      return MetadataGateResult(
        passed: true,
        reason: madeForKids
            ? 'YouTube marked the video as made for kids'
            : 'Trusted kids channel (score: $channelTrustScore)',
        confidence: madeForKids ? 0.9 : 0.85,
      );
    }

    final titleSignals = _kidsIndicators.where(titleLower.contains).length;
    final channelSignals = _kidsIndicators.where(channelLower.contains).length;
    final descriptionSignals = _kidsIndicators.where(descLower.contains).length;
    final tagSignals = tags.where((tag) {
      final lower = tag.toLowerCase();
      return _kidsIndicators.any(lower.contains);
    }).length;
    final totalSignals =
        titleSignals + channelSignals + descriptionSignals + tagSignals;

    // 5. Strong kids metadata signal.
    if (totalSignals >= 2) {
      return MetadataGateResult(
        passed: true,
        reason: 'Multiple kids-specific metadata signals found',
        confidence: 0.7,
      );
    }

    // 6. Narrow category-based approval to obviously kid-oriented metadata.
    if ((categoryId == 10 || categoryId == 27) && totalSignals >= 1) {
      return MetadataGateResult(
        passed: true,
        reason: 'Kid-oriented metadata in a safer YouTube category',
        confidence: 0.6,
      );
    }

    // Default: don't pass — wait for full analysis
    return MetadataGateResult(
      passed: false,
      reason: 'Insufficient metadata signals for approval',
      confidence: 0.3,
    );
  }

  /// Word-boundary check to avoid false positives (e.g. "skilled" matching
  /// "kill"). Uses `\b` regex anchors instead of plain `.contains()`.
  static bool _containsBlockedTerm(String lowerText, String term) {
    return RegExp(
      '\\b${RegExp.escape(term)}\\b',
      caseSensitive: false,
    ).hasMatch(lowerText);
  }

  static const _titleBlocklist = [
    'horror',
    'scary',
    'creepy',
    'murder',
    'kill',
    'dead',
    'death',
    'blood',
    'gore',
    'violence',
    'violent',
    'nsfw',
    'adult',
    '18+',
    'explicit',
    'drugs',
    'drunk',
    'sex',
    'nude',
    'naked',
    'gun',
    'shooting',
    'war',
    'torture',
    'disturbing',
    'graphic',
    'slaughter',
    'suicide',
    'self-harm',
    'abuse',
    'assault',
    'rape',
    'molest',
    'hate',
    'racist',
    'terrorism',
    'extremist',
    'cult',
    'fnaf',
    'five nights',
    'siren head',
    'huggy wuggy',
    'poppy playtime',
    'squid game',
    'elsagate',
    'momo challenge',
  ];

  static const _descriptionBlocklist = [
    'not for children',
    'viewer discretion',
    'mature audiences',
    'age-restricted',
    'parental advisory',
    '18+',
    'nsfw',
    'graphic content',
    'disturbing content',
  ];

  static const _kidsIndicators = [
    'kids',
    'children',
    'toddler',
    'preschool',
    'nursery',
    'baby',
    'educational',
    'learning',
    'abc',
    'sesame',
    'cartoon',
    'animation',
    'family friendly',
    'for kids',
    'cocomelon',
    'bluey',
    'peppa',
    'pinkfong',
  ];
}
