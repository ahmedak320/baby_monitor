import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/screen_time_repository.dart';
import '../../../data/repositories/video_repository.dart';

/// Summary stats for one child on the dashboard.
class ChildDashboardStats {
  final ChildProfile child;
  final int watchedMinutesToday;
  final int videosWatchedToday;
  final int filteredToday;
  final int? limitMinutesToday;

  const ChildDashboardStats({
    required this.child,
    this.watchedMinutesToday = 0,
    this.videosWatchedToday = 0,
    this.filteredToday = 0,
    this.limitMinutesToday,
  });
}

/// Fetch dashboard stats for all children.
final dashboardStatsProvider =
    FutureProvider<List<ChildDashboardStats>>((ref) async {
  final profileRepo = ProfileRepository();
  final screenTimeRepo = ScreenTimeRepository();
  final videoRepo = VideoRepository();

  final children = await profileRepo.getChildren();
  final stats = <ChildDashboardStats>[];

  for (final child in children) {
    final usedSeconds = await screenTimeRepo.getTodayUsageSeconds(child.id);
    final rules = await screenTimeRepo.getRules(child.id);
    final watchHistory = await videoRepo.getWatchHistory(child.id, limit: 100);
    final filteredLog = await videoRepo.getFilteredLog(child.id, limit: 100);

    // Count today's watches
    final today = DateTime.now().toIso8601String().split('T').first;
    final todayWatches = watchHistory
        .where((w) =>
            (w['watched_at'] as String? ?? '').startsWith(today))
        .length;
    final todayFiltered = filteredLog
        .where((f) =>
            (f['filtered_at'] as String? ?? '').startsWith(today))
        .length;

    stats.add(ChildDashboardStats(
      child: child,
      watchedMinutesToday: usedSeconds ~/ 60,
      videosWatchedToday: todayWatches,
      filteredToday: todayFiltered,
      limitMinutesToday: rules?.todayLimit,
    ));
  }

  return stats;
});
