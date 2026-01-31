// =====================================================
// SERVICE : Gestion Financière Unifiée
// Consomme l'API /api/financial/*
// =====================================================

import '../constants/api_constants.dart';
import 'api_service.dart';

class FinancialService {
  final ApiService _apiService = ApiService();

  /// Récupère la vue d'ensemble financière
  /// Paramètres optionnels : dateFrom, dateTo
  Future<Map<String, dynamic>> getFinancialOverview({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final queryParams = <String, String>{};

    if (dateFrom != null) {
      queryParams['dateFrom'] = dateFrom.toIso8601String();
    }

    if (dateTo != null) {
      queryParams['dateTo'] = dateTo.toIso8601String();
    }

    final queryString =
        queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    return _apiService.request(
      'GET',
      '${ApiConstants.baseUrl}/financial/overview$queryString',
    );
  }

  /// Récupère la liste des clients avec dette
  Future<Map<String, dynamic>> getDebts({
    int page = 1,
    int limit = 50,
    double? minDebt,
    String? customerId,
    String? delivererId,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (minDebt != null) {
      queryParams['minDebt'] = minDebt.toString();
    }

    if (customerId != null) {
      queryParams['customerId'] = customerId;
    }

    if (delivererId != null) {
      queryParams['delivererId'] = delivererId;
    }

    final queryString = '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    return _apiService.request(
      'GET',
      '${ApiConstants.baseUrl}/financial/debts$queryString',
    );
  }

  /// Récupère le détail de la dette d'un client
  Future<Map<String, dynamic>> getCustomerDebt(String customerId) async {
    return _apiService.request(
      'GET',
      '${ApiConstants.baseUrl}/financial/debts/$customerId',
    );
  }

  /// Enregistre un paiement
  Future<Map<String, dynamic>> recordPayment({
    required String customerId,
    required double amount,
    String mode = 'cash',
    String? notes,
    List<String>? targetOrders,
  }) async {
    return _apiService.request(
      'POST',
      '${ApiConstants.baseUrl}/financial/payments',
      body: {
        'customerId': customerId,
        'amount': amount,
        'mode': mode,
        if (notes != null) 'notes': notes,
        if (targetOrders != null) 'targetOrders': targetOrders,
      },
    );
  }

  /// Récupère le statut crédit d'un client
  Future<Map<String, dynamic>> getCreditStatus(String customerId) async {
    return _apiService.request(
      'GET',
      '${ApiConstants.baseUrl}/financial/credit/$customerId',
    );
  }

  /// Modifie la limite de crédit d'un client
  Future<Map<String, dynamic>> updateCreditLimit({
    required String customerId,
    required double limit,
  }) async {
    return _apiService.request(
      'PUT',
      '${ApiConstants.baseUrl}/financial/credit/$customerId/limit',
      body: {'limit': limit},
    );
  }

  /// Récupère la liste des alertes crédit
  Future<Map<String, dynamic>> getCreditAlerts() async {
    return _apiService.request(
      'GET',
      '${ApiConstants.baseUrl}/financial/credit/alerts',
    );
  }

  /// Récupère les collections du livreur connecté
  Future<Map<String, dynamic>> getMyCollections() async {
    final result = await _apiService.request('GET', '${ApiConstants.baseUrl}/financial/payments/my-collections');
    return result;
  }
}
