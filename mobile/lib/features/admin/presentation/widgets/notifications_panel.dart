import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/models/notification_model.dart';

class NotificationsPanel extends StatelessWidget {
  final NotificationService notificationService;

  const NotificationsPanel({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notificationService,
      builder: (context, child) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Spacer(),
                    if (notificationService.unreadCount > 0)
                      TextButton(
                        onPressed: () => notificationService.markAllAsRead(),
                        child: Text('Tout lire'),
                      ),
                  ],
                ),
              ),
              // Liste
              Flexible(
                child: notificationService.notifications.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
                            SizedBox(height: 12),
                            Text('Aucune notification', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: notificationService.notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notificationService.notifications[index];
                          return _NotificationTile(
                            notif: notif,
                            onTap: () => notificationService.markAsRead(notif.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotificationTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: notif.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(notif.icon, color: notif.color, size: 20),
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notif.message, style: TextStyle(fontSize: 13)),
      trailing: Text(
        _formatTime(notif.createdAt),
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ),
      onTap: onTap,
      tileColor: notif.isRead ? null : Colors.blue.withValues(alpha: 0.05),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }
}
