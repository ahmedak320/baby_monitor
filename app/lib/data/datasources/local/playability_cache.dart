import 'local_cache.dart';

/// Local cache of videos proven unplayable inside the app.
///
/// This lets the app hide bad embeds immediately even when the network is
/// flaky and the remote Supabase write must be retried later.
class PlayabilityCache {
  static const _blockedKey = 'playability_blocked_video_ids';
  static const _pendingSyncKey = 'playability_pending_sync_video_ids';

  static List<String> getBlockedVideoIds() {
    final data = LocalCache.preferences.get(_blockedKey);
    if (data is List) return data.cast<String>();
    return const [];
  }

  static bool isBlocked(String videoId) {
    return getBlockedVideoIds().contains(videoId);
  }

  static Future<void> markBlocked(
    String videoId, {
    bool pendingRemoteSync = false,
  }) async {
    final blocked = getBlockedVideoIds().toSet()..add(videoId);
    await LocalCache.preferences.put(_blockedKey, blocked.toList());

    if (pendingRemoteSync) {
      final pending = getPendingSyncVideoIds().toSet()..add(videoId);
      await LocalCache.preferences.put(_pendingSyncKey, pending.toList());
    }
  }

  static List<String> getPendingSyncVideoIds() {
    final data = LocalCache.preferences.get(_pendingSyncKey);
    if (data is List) return data.cast<String>();
    return const [];
  }

  static Future<void> clearPendingSyncVideoId(String videoId) async {
    final pending = getPendingSyncVideoIds().toSet()..remove(videoId);
    await LocalCache.preferences.put(_pendingSyncKey, pending.toList());
  }
}
