import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String priority;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.priority,
    this.actionUrl,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] ?? false,
      priority: json['priority'] ?? 'normal',
      actionUrl: json['action_url'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'is_read': isRead,
      'priority': priority,
      'action_url': actionUrl,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  // Helpers pour les icônes et couleurs
  IconData get icon {
    switch (type) {
      case 'payment_recorded':
        return Icons.attach_money;
      case 'debt_cleared':
        return Icons.check_circle;
      case 'favorite_suggested':
        return Icons.lightbulb;
      case 'debt_reminder':
        return Icons.access_time;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'payment_recorded':
        return const Color(0xFF4CAF50); // Green
      case 'debt_cleared':
        return const Color(0xFFFF9800); // Orange
      case 'favorite_suggested':
        return const Color(0xFFFFC107); // Amber
      case 'debt_reminder':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  bool get isHighPriority => priority == 'high' || priority == 'urgent';
}

class NotificationPreferences {
  final bool paymentNotifications;
  final bool debtNotifications;
  final bool favoriteNotifications;
  final bool debtRemindersEnabled;
  final int debtReminderFrequency;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  NotificationPreferences({
    required this.paymentNotifications,
    required this.debtNotifications,
    required this.favoriteNotifications,
    required this.debtRemindersEnabled,
    required this.debtReminderFrequency,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      paymentNotifications: json['payment_notifications'] ?? true,
      debtNotifications: json['debt_notifications'] ?? true,
      favoriteNotifications: json['favorite_notifications'] ?? true,
      debtRemindersEnabled: json['debt_reminders_enabled'] ?? false,
      debtReminderFrequency: json['debt_reminder_frequency'] ?? 7,
      quietHoursStart: json['quiet_hours_start'],
      quietHoursEnd: json['quiet_hours_end'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_notifications': paymentNotifications,
      'debt_notifications': debtNotifications,
      'favorite_notifications': favoriteNotifications,
      'debt_reminders_enabled': debtRemindersEnabled,
      'debt_reminder_frequency': debtReminderFrequency,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }
}
