// =====================================================
// SERVICE: Financial Service v2 - Service financier refactorisé
// Utilise les modèles typés et extensions modernes
// Peut coexister avec l'ancien FinancialService
// =====================================================

import '../constants/api_constants.dart';
import '../extensions/number_extensions.dart';
import '../models/financial_models.dart';
import 'api_service.dart';

/// Exception personnalisée pour les erreurs financières
class FinancialException implements Exception {
  final String message;
  final int? statusCode;
  
  FinancialException(this.message, {this.statusCode});
  
  @override
  String toString() => 'FinancialException: $message';
}

/// Service financier v2 - Implémentation moderne
class FinancialServiceV2 {
  final ApiService _apiService;
  
  FinancialServiceV2({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService();
  
  // Base URL pour l'API v2
  String get _baseUrl => '${ApiConstants.baseUrl}/financial/v2';
  
  // ============================================
  // OVERVIEW & STATS
  // ============================================
  
  /// Récupère la vue d'ensemble financière
  /// 
  /// [dateFrom] et [dateTo] sont optionnels pour filtrer par période
  Future<FinancialOverview> getOverview({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo.toIso8601String();
      }
      
      final queryString = queryParams.isEmpty 
          ? '' 
          : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      
      final response = await _apiService.request(
        'GET', 
        '$_baseUrl/overview$queryString',
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur inconnue');
      }
      
      return FinancialOverview.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FinancialException('Erreur lors du chargement des stats: $e');
    }
  }
  
  // ============================================
  // DEBTS
  // ============================================
  
  /// Récupère la liste des clients avec dette
  /// 
  /// [page] et [limit] pour la pagination
  /// [minDebt] pour filtrer les dettes minimales
  Future<PaginatedDebts> getDebts({
    int page = 1,
    int limit = 50,
    double minDebt = 0,
    String? customerId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'minDebt': minDebt.toString(),
      };
      
      if (customerId != null) {
        queryParams['customerId'] = customerId;
      }
      
      final queryString = '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      
      final response = await _apiService.request(
        'GET',
        '$_baseUrl/debts$queryString',
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur inconnue');
      }
      
      return PaginatedDebts.fromJson(response);
    } catch (e) {
      throw FinancialException('Erreur lors du chargement des dettes: $e');
    }
  }
  
  /// Récupère le détail de la dette d'un client
  Future<CustomerDebt> getCustomerDebt(String customerId) async {
    try {
      final response = await _apiService.request(
        'GET',
        '$_baseUrl/debts/$customerId',
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Client non trouvé');
      }
      
      return CustomerDebt.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FinancialException('Erreur lors du chargement de la dette: $e');
    }
  }
  
  // ============================================
  // PAYMENTS
  // ============================================
  
  /// Enregistre un paiement
  /// 
  /// [customerId] - ID du client
  /// [amount] - Montant du paiement
  /// [mode] - Mode de paiement (cash, check, transfer)
  /// [notes] - Notes optionnelles
  /// [targetOrders] - IDs des commandes à payer (optionnel, FIFO par défaut)
  Future<Payment> recordPayment({
    required String customerId,
    required double amount,
    PaymentMode mode = PaymentMode.cash,
    String? notes,
    List<String>? targetOrders,
  }) async {
    try {
      final body = <String, dynamic>{
        'customerId': customerId,
        'amount': amount,
        'mode': mode.name,
      };
      
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }
      
      if (targetOrders != null && targetOrders.isNotEmpty) {
        body['targetOrders'] = targetOrders;
      }
      
      final response = await _apiService.request(
        'POST',
        '$_baseUrl/payments',
        body: body,
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur lors de l\'enregistrement');
      }
      
      return Payment.fromJson(response['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FinancialException('Erreur lors de l\'enregistrement du paiement: $e');
    }
  }
  
  /// Récupère les collections du livreur connecté (aujourd'hui)
  Future<List<Payment>> getMyCollections() async {
    try {
      final response = await _apiService.request(
        'GET',
        '$_baseUrl/payments/my-collections',
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur inconnue');
      }
      
      final data = response['data'] as List<dynamic>? ?? [];
      return data.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw FinancialException('Erreur lors du chargement des collections: $e');
    }
  }
  
  // ============================================
  // CREDIT
  // ============================================
  
  /// Récupère les alertes crédit (clients proches de leur limite)
  Future<List<CreditAlert>> getCreditAlerts() async {
    try {
      final response = await _apiService.request(
        'GET',
        '$_baseUrl/credit/alerts',
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur inconnue');
      }
      
      final data = response['data'] as List<dynamic>? ?? [];
      return data.map((e) => CreditAlert.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw FinancialException('Erreur lors du chargement des alertes: $e');
    }
  }
  
  /// Met à jour la limite de crédit d'un client
  Future<Map<String, dynamic>> updateCreditLimit({
    required String customerId,
    required double? limit,
  }) async {
    try {
      final response = await _apiService.request(
        'PUT',
        '$_baseUrl/credit/$customerId/limit',
        body: {'limit': limit},
      );
      
      if (response['success'] != true) {
        throw FinancialException(response['error']?.toString() ?? 'Erreur lors de la mise à jour');
      }
      
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      throw FinancialException('Erreur lors de la mise à jour de la limite: $e');
    }
  }
  
  // ============================================
  // HELPERS
  // ============================================
  
  /// Formate un montant en DA
  String formatCurrency(double amount, {int decimals = 0}) {
    return amount.toCurrency(decimals: decimals);
  }
  
  /// Calcule le taux de recouvrement
  double calculateCollectionRate(double collected, double total) {
    if (total <= 0) return 0.0;
    return collected / total;
  }
}
