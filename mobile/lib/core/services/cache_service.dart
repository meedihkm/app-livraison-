import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de cache pour améliorer la réactivité et permettre le mode offline
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  
  // Durées de cache
  static const Duration _shortCache = Duration(minutes: 5);
  static const Duration _mediumCache = Duration(minutes: 30);
  static const Duration _longCache = Duration(hours: 24);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ===== MÉTHODES GÉNÉRIQUES =====
  
  Future<void> setCache(String key, dynamic data, {Duration? duration}) async {
    await init();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': duration?.inMilliseconds ?? _mediumCache.inMilliseconds,
    };
    await _prefs!.setString(key, json.encode(cacheData));
  }

  Future<T?> getCache<T>(String key) async {
    await init();
    final cached = _prefs!.getString(key);
    if (cached == null) return null;
    
    try {
      final cacheData = json.decode(cached);
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int;
      
      // Vérifier expiration
      if (DateTime.now().millisecondsSinceEpoch - timestamp > expiry) {
        await _prefs!.remove(key);
        return null;
      }
      
      return cacheData['data'] as T;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearCache(String key) async {
    await init();
    await _prefs!.remove(key);
  }

  Future<void> clearAllCache() async {
    await init();
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  // ===== CACHE SPÉCIFIQUES =====

  // Produits (cache long - changent rarement)
  Future<void> cacheProducts(List<dynamic> products) async {
    await setCache('cache_products', products, duration: _longCache);
  }

  Future<List<dynamic>?> getCachedProducts() async {
    return await getCache<List<dynamic>>('cache_products');
  }

  // Utilisateurs/Clients (cache moyen)
  Future<void> cacheUsers(List<dynamic> users) async {
    await setCache('cache_users', users, duration: _mediumCache);
  }

  Future<List<dynamic>?> getCachedUsers() async {
    return await getCache<List<dynamic>>('cache_users');
  }

  // Commandes (cache court - changent souvent)
  Future<void> cacheOrders(List<dynamic> orders) async {
    await setCache('cache_orders', orders, duration: _shortCache);
  }

  Future<List<dynamic>?> getCachedOrders() async {
    return await getCache<List<dynamic>>('cache_orders');
  }

  // Livraisons (cache court)
  Future<void> cacheDeliveries(List<dynamic> deliveries) async {
    await setCache('cache_deliveries', deliveries, duration: _shortCache);
  }

  Future<List<dynamic>?> getCachedDeliveries() async {
    return await getCache<List<dynamic>>('cache_deliveries');
  }

  // Dettes (cache moyen)
  Future<void> cacheDebts(List<dynamic> debts) async {
    await setCache('cache_debts', debts, duration: _mediumCache);
  }

  Future<List<dynamic>?> getCachedDebts() async {
    return await getCache<List<dynamic>>('cache_debts');
  }

  // Stats financières par période
  Future<void> cacheFinancialStats(String period, Map<String, dynamic> stats) async {
    await setCache('cache_financial_$period', stats, duration: _shortCache);
  }

  Future<Map<String, dynamic>?> getCachedFinancialStats(String period) async {
    return await getCache<Map<String, dynamic>>('cache_financial_$period');
  }

  // Stats par livreur
  Future<void> cacheDelivererStats(List<dynamic> stats) async {
    await setCache('cache_deliverer_stats', stats, duration: _shortCache);
  }

  Future<List<dynamic>?> getCachedDelivererStats() async {
    return await getCache<List<dynamic>>('cache_deliverer_stats');
  }

  // Historique client
  Future<void> cacheClientHistory(String clientId, List<dynamic> history) async {
    await setCache('cache_client_history_$clientId', history, duration: _mediumCache);
  }

  Future<List<dynamic>?> getCachedClientHistory(String clientId) async {
    return await getCache<List<dynamic>>('cache_client_history_$clientId');
  }

  // ===== UTILITAIRES =====

  /// Vérifie si des données sont en cache (même expirées)
  Future<bool> hasCache(String key) async {
    await init();
    return _prefs!.containsKey(key);
  }

  /// Récupère l'âge du cache en minutes
  Future<int?> getCacheAge(String key) async {
    await init();
    final cached = _prefs!.getString(key);
    if (cached == null) return null;
    
    try {
      final cacheData = json.decode(cached);
      final timestamp = cacheData['timestamp'] as int;
      return ((DateTime.now().millisecondsSinceEpoch - timestamp) / 60000).round();
    } catch (e) {
      return null;
    }
  }
}
