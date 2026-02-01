import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../database/hive_service.dart';
import '../database/sync_service.dart';
import '../storage/secure_storage.dart';
import 'cache_service.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

class ApiService {
  factory ApiService() => _instance;
  ApiService._internal();
  ApiService.forTesting();
  static final ApiService _instance = ApiService._internal();

  final SecureStorage _storage = SecureStorage();
  final HiveService _hive = HiveService();
  final CacheService _cache = CacheService();
  bool _isRefreshing = false;

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final token = await _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Méthode publique pour les appels API génériques
  Future<Map<String, dynamic>> request(
    String method,
    String url, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    return _request(method, url, body: body, includeAuth: includeAuth);
  }

  // Méthode générique avec auto-refresh du token
  Future<Map<String, dynamic>> _request(
    String method,
    String url, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    Future<http.Response> makeRequest() async {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final uri = Uri.parse(url);
      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers);
        case 'POST':
          return http.post(uri, headers: headers, body: body != null ? json.encode(body) : null);
        case 'PUT':
          return http.put(uri, headers: headers, body: body != null ? json.encode(body) : null);
        case 'PATCH':
          return http.patch(uri, headers: headers, body: body != null ? json.encode(body) : null);
        case 'DELETE':
          return http.delete(uri, headers: headers);
        default:
          throw Exception('Méthode HTTP non supportée');
      }
    }

    var response = await makeRequest();

    // Si token expiré, refresh et réessayer
    if (response.statusCode == 401 && includeAuth && !_isRefreshing) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await makeRequest();
      }
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw ApiException(response.statusCode, data['error']?.toString() ?? 'Erreur serveur');
    }
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _isRefreshing = false;
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          await _storage.saveToken(data['accessToken']?.toString() ?? '');
          await _storage.saveRefreshToken(data['refreshToken']?.toString() ?? '');
          _isRefreshing = false;
          return true;
        }
      }

      await _storage.clearAll();
      _isRefreshing = false;
      return false;
    } catch (e) {
      _isRefreshing = false;
      return false;
    }
  }

  // ===== AUTH =====
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.login),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['accessToken'] != null) await _storage.saveToken(data['accessToken'].toString());
      if (data['refreshToken'] != null) await _storage.saveRefreshToken(data['refreshToken'].toString());
      return data;
    } else {
      throw Exception(data['error']?.toString() ?? 'Erreur serveur');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/logout'),
        headers: await _getHeaders(),
        body: json.encode({'refreshToken': refreshToken}),
      );
    } catch (e) {}
    await _storage.clearAll();
  }

  Future<void> logoutAllDevices() async {
    try {
      await _request('POST', '${ApiConstants.baseUrl}/auth/logout-all');
    } catch (e) {}
    await _storage.clearAll();
  }

  Future<Map<String, dynamic>> getMe() async {
    return _request('GET', ApiConstants.me);
  }

  // ===== PRODUCTS =====
  Future<Map<String, dynamic>> getProducts({bool forceRefresh = false}) async {
    // Essayer le cache d'abord
    if (!forceRefresh) {
      final cached = await _cache.getCachedProducts();
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
    }
    final result = await _request('GET', ApiConstants.products);
    if (result['success'] == true && result['data'] is List<dynamic>) {
      await _cache.cacheProducts(result['data'] as List<dynamic>);
    }
    return result;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> product) async {
    final result = await _request('POST', ApiConstants.products, body: product);
    await _cache.clearCache('cache_products'); // Invalider le cache
    return result;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> product) async {
    final result = await _request('PUT', '${ApiConstants.products}/$id', body: product);
    await _cache.clearCache('cache_products');
    return result;
  }

  Future<Map<String, dynamic>> toggleProduct(String id) async {
    final result = await _request('PUT', '${ApiConstants.products}/$id/toggle');
    await _cache.clearCache('cache_products');
    return result;
  }

  Future<Map<String, dynamic>> deleteProduct(String id) async {
    final result = await _request('DELETE', '${ApiConstants.products}/$id');
    await _cache.clearCache('cache_products');
    return result;
  }

  Future<Map<String, dynamic>> reorderProduct(String id, String direction) async =>
      _request('PUT', '${ApiConstants.products}/$id/reorder', body: {'direction': direction});
  Future<Map<String, dynamic>> getProductCategories() async => _request('GET', '${ApiConstants.products}/categories');

  // ===== USERS =====
  Future<Map<String, dynamic>> getUsers({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.getCachedUsers();
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
    }
    final result = await _request('GET', ApiConstants.users);
    if (result['success'] == true && result['data'] is List<dynamic>) {
      await _cache.cacheUsers(result['data'] as List<dynamic>);
    }
    return result;
  }

  Future<Map<String, dynamic>> getDeliverers() async => _request('GET', ApiConstants.deliverers);
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> user) async {
    final result = await _request('POST', ApiConstants.users, body: user);
    await _cache.clearCache('cache_users');
    return result;
  }

  Future<Map<String, dynamic>> deleteUser(String id) async {
    final result = await _request('DELETE', '${ApiConstants.users}/$id');
    await _cache.clearCache('cache_users');
    return result;
  }

  Future<Map<String, dynamic>> toggleUser(String id) async {
    final result = await _request('PUT', '${ApiConstants.users}/$id/toggle');
    await _cache.clearCache('cache_users');
    return result;
  }

  Future<Map<String, dynamic>> updateUserAddress(String userId, String address,
          {double? latitude, double? longitude}) async =>
      _request('PUT', '${ApiConstants.users}/$userId/address',
          body: {'address': address, 'latitude': latitude, 'longitude': longitude});

  Future<Map<String, dynamic>> updateCreditLimit(String userId, double? limit) async =>
      _request('PUT', '${ApiConstants.users}/$userId/credit-limit', body: {'creditLimit': limit});

  // ===== ORDERS =====
  Future<Map<String, dynamic>> getOrders(
      {int page = 1, int limit = 20, bool forceRefresh = false, String? customerId, String? status}) async {
    final cacheKey =
        'orders_p${page}_l$limit${customerId != null ? "_c$customerId" : ""}${status != null ? "_s$status" : ""}';

    // 1. Try Cache if offline or not forced
    if (!forceRefresh) {
      if (!SyncService().isOnline) {
        final cached = _hive.getCachedData(cacheKey);
        if (cached != null) {
          return {'success': true, 'data': cached, 'fromCache': true};
        }
      }
    }

    try {
      var query = 'page=$page&limit=$limit';
      if (customerId != null) query += '&customerId=$customerId';
      if (status != null) query += '&status=$status';

      final result = await _request('GET', '${ApiConstants.orders}?$query');
      if (result['success'] == true && result['data'] != null) {
        await _hive.cacheData(cacheKey, result['data']);
        // Only cache generic list for page 1 if no filters
        if (page == 1 && customerId == null && status == null) await _hive.cacheData('orders', result['data']);
      }
      return result;
    } catch (e) {
      // If request failed (and we checked online status earlier but maybe it failed mid-flight), try cache
      final cached = _hive.getCachedData(cacheKey);
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true, 'offline': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMyOrders({int page = 1, int limit = 20}) async =>
      _request('GET', '${ApiConstants.myOrders}?page=$page&limit=$limit');
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order) async {
    final result = await _request('POST', ApiConstants.orders, body: order);
    await _cache.clearCache('cache_orders');
    return result;
  }

  Future<Map<String, dynamic>> updateOrder(String id, Map<String, dynamic> order) async {
    final result = await _request('PUT', '${ApiConstants.orders}/$id', body: order);
    await _cache.clearCache('cache_orders');
    return result;
  }

  Future<Map<String, dynamic>> lockOrder(String id) async {
    final result = await _request('PUT', '${ApiConstants.orders}/$id/lock');
    await _cache.clearCache('cache_orders');
    return result;
  }

  Future<Map<String, dynamic>> assignDeliverer(String orderId, String delivererId) async {
    final result = await _request('POST', '${ApiConstants.orders}/$orderId/assign', body: {'delivererId': delivererId});
    await _cache.clearCache('cache_orders');
    await _cache.clearCache('cache_deliveries');
    return result;
  }

  // ===== DELIVERIES =====
  Future<Map<String, dynamic>> getDeliveries(
      {int page = 1,
      int limit = 20,
      bool forceRefresh = false,
      String? delivererId,
      String? status,
      String? customerId}) async {
    if (!forceRefresh && page == 1 && delivererId == null && status == null && customerId == null) {
      final cached = await _cache.getCachedDeliveries();
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
    }

    var query = 'page=$page&limit=$limit';
    if (delivererId != null) query += '&delivererId=$delivererId';
    if (status != null) query += '&status=$status';
    if (customerId != null) query += '&customerId=$customerId';

    final result = await _request('GET', '${ApiConstants.deliveries}?$query');
    if (result['success'] == true &&
        result['data'] is List<dynamic> &&
        page == 1 &&
        delivererId == null &&
        status == null &&
        customerId == null) {
      await _cache.cacheDeliveries(result['data'] as List<dynamic>);
    }
    return result;
  }

  Future<Map<String, dynamic>> getDeliveryRoute() async => _request('GET', ApiConstants.deliveryRoute);
  Future<Map<String, dynamic>> getDeliveryHistory() async =>
      _request('GET', '${ApiConstants.baseUrl}/deliveries/history');
  Future<Map<String, dynamic>> getDelivery(String id) async => _request('GET', '${ApiConstants.deliveries}/$id');
  Future<Map<String, dynamic>> updateDeliveryStatus(String id, Map<String, dynamic> status) async {
    final result = await _request('PUT', '${ApiConstants.deliveries}/$id/status', body: status);
    await _cache.clearCache('cache_deliveries');
    await _cache.clearCache('cache_orders');
    return result;
  }

  // ===== FINANCIAL =====
  Future<Map<String, dynamic>> getDailyFinancial() async => _request('GET', ApiConstants.dailyFinancial);
  Future<Map<String, dynamic>> getDebts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.getCachedDebts();
      if (cached != null) {
        return {'success': true, 'data': cached, 'fromCache': true};
      }
    }
    try {
      final result = await _request('GET', ApiConstants.debts);
      // Backend retourne { data, summary, pagination }
      if (result['data'] is List<dynamic>) {
        await _cache.cacheDebts(result['data'] as List<dynamic>);
        return {
          'success': true,
          'data': result['data'],
          'summary': result['summary'],
          'pagination': result['pagination']
        };
      }
      return {'success': false, 'data': []};
    } catch (e) {
      print('Error getting debts: $e');
      return {'success': false, 'data': [], 'error': e.toString()};
    }
  }

  // ===== LOCATION =====
  Future<Map<String, dynamic>> updateDelivererLocation(double lat, double lng) async =>
      _request('POST', ApiConstants.deliverersLocation, body: {'latitude': lat, 'longitude': lng});
  Future<Map<String, dynamic>> getDeliverersLocations() async => _request('GET', ApiConstants.deliverersLocations);
  Future<Map<String, dynamic>> getClientsLocations() async =>
      _request('GET', '${ApiConstants.baseUrl}/users/clients-locations');
  Future<Map<String, dynamic>> getDelivererHistory(String delivererId, String date) async =>
      _request('GET', '${ApiConstants.deliveries}/$delivererId/history?date=$date');

  // ===== ORGANIZATION =====
  Future<Map<String, dynamic>> getOrganizationSettings() async =>
      _request('GET', '${ApiConstants.baseUrl}/organization/settings');
  Future<Map<String, dynamic>> updateOrganizationSettings(Map<String, dynamic> settings) async =>
      _request('PUT', '${ApiConstants.baseUrl}/organization/settings', body: settings);

  // ===== KITCHEN =====
  Future<Map<String, dynamic>> getKitchenOrders() async => _request('GET', '${ApiConstants.baseUrl}/orders/kitchen');
  Future<Map<String, dynamic>> updateKitchenOrderStatus(String orderId, String status) async =>
      _request('PUT', '${ApiConstants.baseUrl}/orders/$orderId/kitchen-status', body: {'status': status});

  // ===== AUDIT =====
  Future<Map<String, dynamic>> getAuditLogs({int limit = 100, int offset = 0, String? action}) async {
    var url = '${ApiConstants.auditLogs}?limit=$limit&offset=$offset';
    if (action != null) url += '&action=$action';
    return _request('GET', url);
  }

  // ===== DEBT (Refactorisé) =====

  /// Récupère la dette détaillée d'un client
  Future<Map<String, dynamic>> getCustomerDebt(String customerId) async {
    try {
      final result = await _request('GET', '${ApiConstants.baseUrl}/debts/customers/$customerId');
      return result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : {};
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) return {};
      rethrow;
    }
  }

  /// Liste tous les clients avec dette
  Future<Map<String, dynamic>> getDebtsList({
    int page = 1,
    int limit = 50,
    double minDebt = 0,
    String? customerId,
    String? delivererId,
    String? dateFrom,
    String? dateTo,
  }) async {
    var url = '${ApiConstants.baseUrl}/debts?page=$page&limit=$limit&min_debt=$minDebt';
    if (customerId != null) url += '&customer_id=$customerId';
    if (delivererId != null) url += '&deliverer_id=$delivererId';
    if (dateFrom != null) url += '&date_from=$dateFrom';
    if (dateTo != null) url += '&date_to=$dateTo';
    return _request('GET', url);
  }

  /// Récupère les statistiques globales des dettes
  Future<Map<String, dynamic>> getDebtStats() async {
    final result = await _request('GET', '${ApiConstants.baseUrl}/debts/stats');
    return result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : {};
  }

  // ===== PAYMENTS (Refactorisé) =====

  /// Enregistre un paiement de dette
  Future<Map<String, dynamic>> recordPayment({
    required String customerId,
    required double amount,
    String mode = 'cash',
    String? deliveryId,
    List<String>? targetOrders,
    String? notes,
  }) async {
    final result = await _request('POST', '${ApiConstants.baseUrl}/payments', body: {
      'customerId': customerId,
      'amount': amount,
      'mode': mode,
      if (deliveryId != null) 'deliveryId': deliveryId,
      if (targetOrders != null) 'targetOrders': targetOrders,
      if (notes != null) 'notes': notes,
    });

    // Invalider cache
    await _cache.clearCache('cache_debts');
    await _cache.clearCache('cache_orders');

    return result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : {};
  }

  /// Récupère l'historique des paiements
  Future<Map<String, dynamic>> getPaymentHistory({
    int page = 1,
    int limit = 50,
    String? customerId,
    String? collectorId,
    String? dateFrom,
    String? dateTo,
  }) async {
    var url = '${ApiConstants.baseUrl}/payments/history?page=$page&limit=$limit';
    if (customerId != null) url += '&customer_id=$customerId';
    if (collectorId != null) url += '&collector_id=$collectorId';
    if (dateFrom != null) url += '&date_from=$dateFrom';
    if (dateTo != null) url += '&date_to=$dateTo';
    return _request('GET', url);
  }

  /// Récupère les collections du livreur connecté
  Future<Map<String, dynamic>> getMyCollections() async {
    final result = await _request('GET', '${ApiConstants.baseUrl}/payments/my-collections');
    return result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : {};
  }

  /// Récupère les statistiques des paiements
  Future<Map<String, dynamic>> getPaymentStats() async {
    final result = await _request('GET', '${ApiConstants.baseUrl}/payments/stats');
    return result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : {};
  }

  // ===== DEBT (Ancienne méthode - Déprécié) =====
  @Deprecated('Utiliser recordPayment() à la place')
  Future<Map<String, dynamic>> recordDebtPayment(Map<String, dynamic> paymentData) async {
    return recordPayment(
      customerId: (paymentData['customerId'] ?? paymentData['clientId'])?.toString() ?? '',
      amount: (paymentData['amount'] as num?)?.toDouble() ?? 0.0,
      mode: paymentData['mode']?.toString() ?? 'cash',
      deliveryId: paymentData['deliveryId']?.toString(),
      targetOrders: paymentData['targetOrders'] is List<dynamic> 
          ? (paymentData['targetOrders'] as List<dynamic>).whereType<String>().toList()
          : null,
      notes: paymentData['notes']?.toString(),
    );
  }

  // ===== PACKAGING (Feature 3) =====
  Future<Map<String, dynamic>> getPackagingTypes() async => _request('GET', '${ApiConstants.baseUrl}/packaging/types');

  Future<Map<String, dynamic>> createPackagingType(Map<String, dynamic> data) async =>
      _request('POST', '${ApiConstants.baseUrl}/packaging/types', body: data);

  Future<Map<String, dynamic>> updatePackagingType(String id, Map<String, dynamic> data) async =>
      _request('PUT', '${ApiConstants.baseUrl}/packaging/types/$id', body: data);

  Future<Map<String, dynamic>> getCustomerPackagingBalance(String customerId) async =>
      _request('GET', '${ApiConstants.baseUrl}/packaging/customers/$customerId/balance');

  Future<Map<String, dynamic>> getCustomerPackagingHistory(String customerId, {int limit = 50, int offset = 0}) async =>
      _request('GET', '${ApiConstants.baseUrl}/packaging/customers/$customerId/history?limit=$limit&offset=$offset');

  Future<Map<String, dynamic>> recordPackagingDeposit(Map<String, dynamic> data) async =>
      _request('POST', '${ApiConstants.baseUrl}/packaging/deposits', body: data);

  Future<Map<String, dynamic>> getPackagingSummary() async =>
      _request('GET', '${ApiConstants.baseUrl}/packaging/summary');

  // ===== RECURRING ORDERS (Refactorisé) =====

  /// Liste les commandes récurrentes
  Future<Map<String, dynamic>> getRecurringOrders() async =>
      _request('GET', '${ApiConstants.baseUrl}/recurring-orders');

  /// Récupère une commande récurrente par ID
  Future<Map<String, dynamic>> getRecurringOrderById(String id) async =>
      _request('GET', '${ApiConstants.baseUrl}/recurring-orders/$id');

  /// Crée une nouvelle commande récurrente
  Future<Map<String, dynamic>> createRecurringOrder(Map<String, dynamic> data) async =>
      _request('POST', '${ApiConstants.baseUrl}/recurring-orders', body: data);

  /// Met à jour une commande récurrente
  Future<Map<String, dynamic>> updateRecurringOrder(String id, Map<String, dynamic> data) async =>
      _request('PUT', '${ApiConstants.baseUrl}/recurring-orders/$id', body: data);

  /// Supprime une commande récurrente
  Future<Map<String, dynamic>> deleteRecurringOrder(String id) async =>
      _request('DELETE', '${ApiConstants.baseUrl}/recurring-orders/$id');

  /// Active/désactive une commande récurrente
  Future<Map<String, dynamic>> toggleRecurringOrder(String id) async =>
      _request('POST', '${ApiConstants.baseUrl}/recurring-orders/$id/toggle');

  /// Liste toutes les commandes récurrentes (Admin)
  Future<Map<String, dynamic>> getAdminRecurringOrders({bool? active}) async {
    var query = '';
    if (active != null) query = '?active=$active';
    return _request('GET', '${ApiConstants.baseUrl}/recurring-orders/admin/all$query');
  }

  // ===== FAVORITES =====

  /// Récupère les commandes favorites de l'utilisateur
  Future<Map<String, dynamic>> getMyFavorites() async =>
      _request('GET', '${ApiConstants.baseUrl}/favorites/my-favorites');

  /// Récupère les préférences de favoris
  Future<Map<String, dynamic>> getFavoritePreferences() async =>
      _request('GET', '${ApiConstants.baseUrl}/favorites/preferences');

  /// Met à jour les préférences de favoris
  Future<Map<String, dynamic>> updateFavoritePreferences(Map<String, dynamic> preferences) async =>
      _request('PUT', '${ApiConstants.baseUrl}/favorites/preferences', body: preferences);

  /// Détecte un pattern de commande
  Future<Map<String, dynamic>> detectOrderPattern(List<Map<String, dynamic>> items) async =>
      _request('POST', '${ApiConstants.baseUrl}/favorites/detect-pattern', body: {'items': items});

  /// Crée un favori
  Future<Map<String, dynamic>> createFavorite({
    required String name,
    required List<Map<String, dynamic>> items,
    bool fromPattern = false,
  }) async =>
      _request('POST', '${ApiConstants.baseUrl}/favorites/create',
          body: {'name': name, 'items': items, 'fromPattern': fromPattern});

  /// Utilise un favori (incrémente compteur)
  Future<Map<String, dynamic>> useFavorite(String id) async =>
      _request('POST', '${ApiConstants.baseUrl}/favorites/$id/use');

  /// Met à jour un favori
  Future<Map<String, dynamic>> updateFavorite(String id, String name, List<Map<String, dynamic>> items) async =>
      _request('PUT', '${ApiConstants.baseUrl}/favorites/$id', body: {'name': name, 'items': items});

  /// Supprime un favori
  Future<Map<String, dynamic>> deleteFavorite(String id) async =>
      _request('DELETE', '${ApiConstants.baseUrl}/favorites/$id');

  /// Récupère les statistiques des favoris (Admin)
  Future<Map<String, dynamic>> getFavoriteStats() async => _request('GET', '${ApiConstants.baseUrl}/favorites/stats');

  // ===== NOTIFICATIONS =====

  /// Récupère les notifications de l'utilisateur
  Future<Map<String, dynamic>> getNotifications({int limit = 50, bool unreadOnly = false}) async =>
      _request('GET', '${ApiConstants.baseUrl}/notifications?limit=$limit&unreadOnly=$unreadOnly');

  /// Compte les notifications non lues
  Future<Map<String, dynamic>> getUnreadNotificationsCount() async =>
      _request('GET', '${ApiConstants.baseUrl}/notifications/unread-count');

  /// Marque une notification comme lue
  Future<Map<String, dynamic>> markNotificationRead(String id) async =>
      _request('PUT', '${ApiConstants.baseUrl}/notifications/$id/read');

  /// Marque toutes les notifications comme lues
  Future<Map<String, dynamic>> markAllNotificationsRead() async =>
      _request('PUT', '${ApiConstants.baseUrl}/notifications/read-all');

  /// Supprime une notification
  Future<Map<String, dynamic>> deleteNotification(String id) async =>
      _request('DELETE', '${ApiConstants.baseUrl}/notifications/$id');

  /// Récupère les préférences de notifications
  Future<Map<String, dynamic>> getNotificationPreferences() async =>
      _request('GET', '${ApiConstants.baseUrl}/notifications/preferences');

  /// Met à jour les préférences de notifications
  Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> preferences) async =>
      _request('PUT', '${ApiConstants.baseUrl}/notifications/preferences', body: preferences);

  /// Envoie les rappels de dette (Admin)
  Future<Map<String, dynamic>> sendDebtReminders() async =>
      _request('POST', '${ApiConstants.baseUrl}/notifications/send-debt-reminders');

  /// Récupère les statistiques des notifications (Admin)
  Future<Map<String, dynamic>> getNotificationStats() async =>
      _request('GET', '${ApiConstants.baseUrl}/notifications/stats');
}
