import 'local_cache.dart';

/// Cache for approved video IDs per child profile.
/// Allows offline browsing of previously approved content.
class ApprovedCache {
  static const _keyPrefix = 'approved_';

  /// Get cached approved video IDs for a child.
  static List<String> getApprovedVideoIds(String childId) {
    final data = LocalCache.approvedVideos.get('$_keyPrefix$childId');
    if (data == null) return [];
    final list = data['video_ids'];
    if (list is List) return list.cast<String>();
    return [];
  }

  /// Cache approved video IDs for a child.
  static Future<void> setApprovedVideoIds(
    String childId,
    List<String> videoIds,
  ) async {
    await LocalCache.approvedVideos.put('$_keyPrefix$childId', {
      'video_ids': videoIds,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  /// Add a single video ID to the approved cache.
  static Future<void> addApprovedVideoId(String childId, String videoId) async {
    final current = getApprovedVideoIds(childId);
    if (!current.contains(videoId)) {
      current.add(videoId);
      await setApprovedVideoIds(childId, current);
    }
  }

  /// Remove a single video ID from the approved cache.
  static Future<void> removeApprovedVideoId(
    String childId,
    String videoId,
  ) async {
    final current = getApprovedVideoIds(childId);
    current.remove(videoId);
    await setApprovedVideoIds(childId, current);
  }

  /// Check if a video is in the approved cache.
  static bool isApproved(String childId, String videoId) {
    return getApprovedVideoIds(childId).contains(videoId);
  }

  /// Clear cache for a specific child.
  static Future<void> clearChild(String childId) async {
    await LocalCache.approvedVideos.delete('$_keyPrefix$childId');
  }
}
