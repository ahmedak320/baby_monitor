import 'package:flutter/material.dart';

import '../../../domain/services/notification_service.dart';

/// A dismissible notification banner displayed on the dashboard.
class NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const NotificationBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor(notification.type);

    return Dismissible(
      key: ValueKey('${notification.type}_${notification.createdAt}'),
      onDismissed: (_) => onDismiss(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: color.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconAndColor(NotificationType type) {
    return switch (type) {
      NotificationType.dailySummary => (Icons.summarize, Colors.blue),
      NotificationType.filteredContentAlert => (Icons.shield, Colors.orange),
      NotificationType.screenTimeReport => (Icons.timer, Colors.purple),
      NotificationType.ageTransition => (Icons.cake, Colors.green),
      NotificationType.analysisLimitWarning => (Icons.warning, Colors.red),
    };
  }
}
