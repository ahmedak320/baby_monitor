import 'dart:async';

import '../../data/datasources/local/approved_cache.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../utils/age_calculator.dart';

/// Service that periodically syncs data from Supabase to local cache
/// for faster app startup and offline support.
class BackgroundSyncService {
  Timer? _syncTimer;
  final ProfileRepository _profileRepo;
  final VideoRepository _videoRepo;
  bool _isSyncing = false;

  BackgroundSyncService({
    ProfileRepository? profileRepo,
    VideoRepository? videoRepo,
  }) : _profileRepo = profileRepo ?? ProfileRepository(),
       _videoRepo = videoRepo ?? VideoRepository();

  /// Start periodic background sync (every 15 minutes).
  void startPeriodicSync() {
    // Run immediately, then every 15 minutes
    _syncAll();
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) => _syncAll());
  }

  /// Stop periodic sync.
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Run a one-time sync of all data.
  Future<void> syncNow() async {
    await _syncAll();
  }

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncApprovedVideos();
    } catch (_) {
      // Silently fail — background sync shouldn't crash the app
    } finally {
      _isSyncing = false;
    }
  }

  /// Refresh approved video caches for all children.
  Future<void> _syncApprovedVideos() async {
    final children = await _profileRepo.getChildren();

    for (final child in children) {
      final age = AgeCalculator.yearsFromDob(child.dateOfBirth);
      final videos = await _videoRepo.getApprovedVideos(
        childId: child.id,
        childAge: age,
        limit: 100,
      );

      final videoIds = videos.map((v) => v.videoId).toList();
      await ApprovedCache.setApprovedVideoIds(child.id, videoIds);
    }
  }
}
