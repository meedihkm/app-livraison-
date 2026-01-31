import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/secure_storage.dart';
import '../constants/api_constants.dart';

class FavoriteService {
  final SecureStorage _storage = SecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // 1. Récupérer mes favoris
  // ============================================
  Future<Map<String, dynamic>> getMyFavorites() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/favorites/my-favorites'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 2. Créer un favori
  // ============================================
  Future<Map<String, dynamic>> createFavorite({
    required String name,
    required List<Map<String, dynamic>> items,
    bool fromPattern = false,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/favorites/create'),
        headers: headers,
        body: json.encode({
          'name': name,
          'items': items,
          'fromPattern': fromPattern,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 3. Mettre à jour un favori
  // ============================================
  Future<Map<String, dynamic>> updateFavorite({
    required String favoriteId,
    required String name,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/favorites/$favoriteId'),
        headers: headers,
        body: json.encode({
          'name': name,
          'items': items,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 4. Supprimer un favori
  // ============================================
  Future<Map<String, dynamic>> deleteFavorite(String favoriteId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/favorites/$favoriteId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 5. Enregistrer utilisation d'un favori
  // ============================================
  Future<Map<String, dynamic>> useFavorite(String favoriteId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/favorites/$favoriteId/use'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 6. Détecter un pattern
  // ============================================
  Future<Map<String, dynamic>> detectPattern({
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/favorites/detect-pattern'),
        headers: headers,
        body: json.encode({'items': items}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 7. Récupérer préférences
  // ============================================
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/favorites/preferences'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // ============================================
  // 8. Mettre à jour préférences
  // ============================================
  Future<Map<String, dynamic>> updatePreferences({
    required bool favoriteOrdersEnabled,
    required bool autoSuggestEnabled,
    required int minPatternCount,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/favorites/preferences'),
        headers: headers,
        body: json.encode({
          'favorite_orders_enabled': favoriteOrdersEnabled,
          'auto_suggest_enabled': autoSuggestEnabled,
          'min_pattern_count': minPatternCount,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
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
        Uri.parse('${ApiConstants.baseUrl}/favorites/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }
}
