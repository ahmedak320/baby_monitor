import '../../data/datasources/local/preferences_cache.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/screen_time_repository.dart';
import '../../data/repositories/video_repository.dart';

/// Types of notifications the app can send.
enum NotificationType {
  dailySummary,
  filteredContentAlert,
  screenTimeReport,
  ageTransition,
  analysisLimitWarning,
}

/// A notification to display to the parent.
class AppNotification {
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data,
  });
}

/// Service for generating in-app notifications.
/// Uses local state + Hive to track what's been shown.
class NotificationService {
  final ProfileRepository _profileRepo;
  final ScreenTimeRepository _screenTimeRepo;
  final VideoRepository _videoRepo;

  NotificationService({
    ProfileRepository? profileRepo,
    ScreenTimeRepository? screenTimeRepo,
    VideoRepository? videoRepo,
  })  : _profileRepo = profileRepo ?? ProfileRepository(),
        _screenTimeRepo = screenTimeRepo ?? ScreenTimeRepository(),
        _videoRepo = videoRepo ?? VideoRepository();

  /// Generate pending notifications that haven't been shown today.
  Future<List<AppNotification>> getPendingNotifications() async {
    final notifications = <AppNotification>[];
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;

    // Check if daily summary was already shown today
    final lastSummary = PreferencesCache.getLastNotificationDate(
      NotificationType.dailySummary.name,
    );

    if (lastSummary != today && now.hour >= 18) {
      final summary = await _generateDailySummary();
      if (summary != null) notifications.add(summary);
    }

    // Check for filtered content alerts (batched, not per-video)
    final lastFilteredAlert = PreferencesCache.getLastNotificationDate(
      NotificationType.filteredContentAlert.name,
    );
    if (lastFilteredAlert != today) {
      final alert = await _generateFilteredContentAlert();
      if (alert != null) notifications.add(alert);
    }

    // Check for screen time report
    final lastScreenTimeReport = PreferencesCache.getLastNotificationDate(
      NotificationType.screenTimeReport.name,
    );
    if (lastScreenTimeReport != today && now.hour >= 20) {
      final report = await _generateScreenTimeReport();
      if (report != null) notifications.add(report);
    }

    return notifications;
  }

  /// Mark a notification type as shown today.
  Future<void> markShown(NotificationType type) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    await PreferencesCache.setLastNotificationDate(type.name, today);
  }

  Future<AppNotification?> _generateDailySummary() async {
    final children = await _profileRepo.getChildren();
    if (children.isEmpty) return null;

    final lines = <String>[];
    for (final child in children) {
      final usedSeconds =
          await _screenTimeRepo.getTodayUsageSeconds(child.id);
      final watchHistory =
          await _videoRepo.getWatchHistory(child.id, limit: 100);
      final filteredLog =
          await _videoRepo.getFilteredLog(child.id, limit: 100);

      final today = DateTime.now().toIso8601String().split('T').first;
      final todayWatches = watchHistory
          .where((w) =>
              (w['watched_at'] as String? ?? '').startsWith(today))
          .length;
      final todayFiltered = filteredLog
          .where((f) =>
              (f['filtered_at'] as String? ?? '').startsWith(today))
          .length;

      final minutes = usedSeconds ~/ 60;
      lines.add(
        '${child.name}: ${minutes}m watched, '
        '$todayWatches videos, $todayFiltered filtered',
      );
    }

    if (lines.every((l) => l.contains('0m watched'))) return null;

    return AppNotification(
      type: NotificationType.dailySummary,
      title: 'Daily Summary',
      body: lines.join('\n'),
      createdAt: DateTime.now(),
    );
  }

  Future<AppNotification?> _generateFilteredContentAlert() async {
    final children = await _profileRepo.getChildren();
    if (children.isEmpty) return null;

    int totalFiltered = 0;
    final today = DateTime.now().toIso8601String().split('T').first;

    for (final child in children) {
      final filteredLog =
          await _videoRepo.getFilteredLog(child.id, limit: 100);
      totalFiltered += filteredLog
          .where((f) =>
              (f['filtered_at'] as String? ?? '').startsWith(today))
          .length;
    }

    if (totalFiltered == 0) return null;

    return AppNotification(
      type: NotificationType.filteredContentAlert,
      title: 'Content Filtered Today',
      body: '$totalFiltered video${totalFiltered == 1 ? '' : 's'} '
          'filtered today. Review in the Filtered Content screen.',
      createdAt: DateTime.now(),
    );
  }

  Future<AppNotification?> _generateScreenTimeReport() async {
    final children = await _profileRepo.getChildren();
    if (children.isEmpty) return null;

    final lines = <String>[];
    for (final child in children) {
      final usedSeconds =
          await _screenTimeRepo.getTodayUsageSeconds(child.id);
      final rules = await _screenTimeRepo.getRules(child.id);
      final limitMinutes = rules?.todayLimit;

      final minutes = usedSeconds ~/ 60;
      if (limitMinutes != null) {
        final pct = ((minutes / limitMinutes) * 100).round();
        lines.add('${child.name}: ${minutes}m / ${limitMinutes}m ($pct%)');
      } else {
        lines.add('${child.name}: ${minutes}m (no limit set)');
      }
    }

    return AppNotification(
      type: NotificationType.screenTimeReport,
      title: 'Screen Time Report',
      body: lines.join('\n'),
      createdAt: DateTime.now(),
    );
  }
}
