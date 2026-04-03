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
  /// Uses a single atomic put() to prevent read-modify-write races.
  static Future<void> addApprovedVideoId(String childId, String videoId) async {
    final current = getApprovedVideoIds(childId);
    if (current.contains(videoId)) return;
    final updated = [...current, videoId];
    await LocalCache.approvedVideos.put('$_keyPrefix$childId', {
      'video_ids': updated,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a single video ID from the approved cache.
  /// Uses a single atomic put() to prevent read-modify-write races.
  static Future<void> removeApprovedVideoId(
    String childId,
    String videoId,
  ) async {
    final current = getApprovedVideoIds(childId);
    final updated = current.where((id) => id != videoId).toList();
    await LocalCache.approvedVideos.put('$_keyPrefix$childId', {
      'video_ids': updated,
      'cached_at': DateTime.now().toIso8601String(),
    });
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
