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
    double channelTrustScore = 0.0,
  }) {
    final titleLower = title.toLowerCase();
    final descLower = description.toLowerCase();

    // 1. Title keyword blocklist — immediate reject
    for (final word in _titleBlocklist) {
      if (titleLower.contains(word)) {
        return MetadataGateResult(
          passed: false,
          reason: 'Title contains blocked term: $word',
          confidence: 0.9,
        );
      }
    }

    // 2. Description keyword blocklist
    for (final word in _descriptionBlocklist) {
      if (descLower.contains(word)) {
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
    if (isKidsChannel || channelTrustScore >= 0.8) {
      return MetadataGateResult(
        passed: true,
        reason: 'Trusted kids channel (score: $channelTrustScore)',
        confidence: 0.85,
      );
    }

    // 5. YouTube category check — safer categories
    // 10=Music, 1=Film, 24=Entertainment, 22=People, 27=Education
    final safeCategories = {10, 24, 27, 1};
    if (safeCategories.contains(categoryId)) {
      // Safe category + no blocklist hits — moderate confidence
      return MetadataGateResult(
        passed: true,
        reason: 'Safe YouTube category ($categoryId)',
        confidence: 0.65,
      );
    }

    // 6. Tags check — if tags contain kids-related terms
    final kidsTags = tags.where((t) {
      final tl = t.toLowerCase();
      return _kidsIndicators.any((k) => tl.contains(k));
    }).toList();

    if (kidsTags.length >= 2) {
      return MetadataGateResult(
        passed: true,
        reason: 'Multiple kids-related tags found',
        confidence: 0.6,
      );
    }

    // 7. Title has kids indicators
    if (_kidsIndicators.any((k) => titleLower.contains(k))) {
      return MetadataGateResult(
        passed: true,
        reason: 'Title indicates kids content',
        confidence: 0.55,
      );
    }

    // Default: don't pass — wait for full analysis
    return MetadataGateResult(
      passed: false,
      reason: 'Insufficient metadata signals for approval',
      confidence: 0.3,
    );
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
