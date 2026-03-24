import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/notification_service.dart';

/// Provides pending notifications for the dashboard.
final pendingNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final service = NotificationService();
  return service.getPendingNotifications();
});
