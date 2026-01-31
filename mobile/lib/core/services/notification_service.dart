import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SecureStorage _storage = SecureStorage();
  static const String appId = "YOUR_ONESIGNAL_APP_ID";

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // 1. Récupérer les notifications
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
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      // Retourner données vides en cas d'erreur pour ne pas bloquer l'UI
      return {'success': false, 'data': []};
    }
  }

  // ============================================
  // 2. Compteur non lues
  // ============================================
  Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/unread-count'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0; // Silencieux pour ne pas bloquer l'UI
    }
  }

  // ============================================
  // 3. Marquer comme lue
  // ============================================
  Future<Map<String, dynamic>> markAsRead(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/$id/read'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 4. Tout marquer comme lu
  // ============================================
  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/read-all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 5. Supprimer une notification
  // ============================================
  Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/notifications/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 6. Récupérer préférences
  // ============================================
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/preferences'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 7. Mettre à jour préférences
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
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 8. Envoyer rappels dette (Admin)
  // ============================================
  Future<Map<String, dynamic>> sendDebtReminders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notifications/send-debt-reminders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 9. Statistiques (Admin)
  // ============================================
  Future<Map<String, dynamic>> getStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
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
