import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SecureStorage _storage = SecureStorage();
  static const String appId = "YOUR_ONESIGNAL_APP_ID";

  // Propriétés synchrones pour le panel de notifications
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // 1. Charger les notifications (sync + notify)
  // ============================================
  Future<void> loadNotifications({int limit = 50, bool unreadOnly = false}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications?limit=$limit&unreadOnly=$unreadOnly'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        final data = result['data'];
        if (data is List<dynamic>) {
          _notifications = data
              .whereType<Map<String, dynamic>>()
              .map((json) => AppNotification.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      // Silencieux pour ne pas bloquer l'UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // 2. Récupérer le compteur non lues
  // ============================================
  Future<void> loadUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/unread-count'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        final data = result['data'] as Map<String, dynamic>?;
        _unreadCount = (data?['count'] as int?) ?? 0;
        notifyListeners();
      }
    } catch (e) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  // ============================================
  // 3. Récupérer les notifications (API)
  // ============================================
  Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    bool unreadOnly = false
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications?limit=$limit&unreadOnly=$unreadOnly'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      // Retourner données vides en cas d'erreur pour ne pas bloquer l'UI
      return {'success': false, 'data': []};
    }
  }

  // ============================================
  // 4. Compteur non lues (API)
  // ============================================
  Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/unread-count'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        return (result['data'] as Map<String, dynamic>?)?['count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      return 0; // Silencieux pour ne pas bloquer l'UI
    }
  }

  // ============================================
  // 5. Marquer comme lue
  // ============================================
  Future<Map<String, dynamic>> markAsRead(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/$id/read'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: _notifications[index].id,
            type: _notifications[index].type,
            title: _notifications[index].title,
            message: _notifications[index].message,
            data: _notifications[index].data,
            isRead: true,
            priority: _notifications[index].priority,
            actionUrl: _notifications[index].actionUrl,
            createdAt: _notifications[index].createdAt,
            readAt: DateTime.now(),
          );
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
          notifyListeners();
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 6. Tout marquer comme lu
  // ============================================
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/read-all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        _notifications = _notifications.map((n) => AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          message: n.message,
          data: n.data,
          isRead: true,
          priority: n.priority,
          actionUrl: n.actionUrl,
          createdAt: n.createdAt,
          readAt: DateTime.now(),
        )).toList();
        _unreadCount = 0;
        notifyListeners();
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 7. Supprimer une notification
  // ============================================
  Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/notifications/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        final wasUnread = _notifications.firstWhere((n) => n.id == id, orElse: () => _notifications.first).isRead == false;
        _notifications.removeWhere((n) => n.id == id);
        if (wasUnread && _unreadCount > 0) {
          _unreadCount--;
        }
        notifyListeners();
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 8. Récupérer préférences
  // ============================================
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/preferences'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 9. Mettre à jour préférences
  // ============================================
  Future<Map<String, dynamic>> updatePreferences({
    bool? paymentNotifications,
    bool? debtNotifications,
    bool? favoriteNotifications,
    bool? debtRemindersEnabled,
    int? debtReminderFrequency,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      
      if (paymentNotifications != null) body['payment_notifications'] = paymentNotifications;
      if (debtNotifications != null) body['debt_notifications'] = debtNotifications;
      if (favoriteNotifications != null) body['favorite_notifications'] = favoriteNotifications;
      if (debtRemindersEnabled != null) body['debt_reminders_enabled'] = debtRemindersEnabled;
      if (debtReminderFrequency != null) body['debt_reminder_frequency'] = debtReminderFrequency;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/preferences'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 10. Envoyer rappels dette (Admin)
  // ============================================
  Future<Map<String, dynamic>> sendDebtReminders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/send-debt-reminders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 11. Statistiques (Admin)
  // ============================================
  Future<Map<String, dynamic>> getStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // OneSignal Push Notifications
  // ============================================
  Future<void> init() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(appId);
    await OneSignal.Notifications.requestPermission(true);
  }

  Future<void> login(String userId) async {
    await OneSignal.login(userId);
  }

  Future<void> logout() async {
    await OneSignal.logout();
  }

  void setNotificationHandler(GlobalKey<NavigatorState> navigatorKey) {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] != null) {
        _handleDeepLink(data, navigatorKey);
      }
    });
  }

  void _handleDeepLink(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey) {
    final type = data['type'];
    final id = data['id'];

    if (type == 'order' && id != null) {
      print('Deep link to Order $id');
    }
  }
}
