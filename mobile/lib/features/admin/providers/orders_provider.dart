import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/order_model.dart';

class OrdersProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getOrders();
      if (response['success'] == true) {
        _orders = (response['data'] as List)
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> lockOrder(String orderId) async {
    try {
      await _apiService.lockOrder(orderId);
      await loadOrders(); // Refresh the list
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignDeliverer(String orderId, String delivererId) async {
    try {
      await _apiService.assignDeliverer(orderId, delivererId);
      await loadOrders(); // Refresh the list
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}