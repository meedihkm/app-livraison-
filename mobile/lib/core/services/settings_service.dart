import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import 'api_service.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final SecureStorage _storage = SecureStorage();
  final ApiService _apiService = ApiService();

  // Valeurs par défaut
  double _debtAlertThreshold = 5000;
  double _debtBlockThreshold = 10000;
  bool _autoBlockOnDebt = false;
  double _tvaRate = 19;
  bool _kitchenMode = false;

  // Getters
  double get debtAlertThreshold => _debtAlertThreshold;
  double get debtBlockThreshold => _debtBlockThreshold;
  bool get autoBlockOnDebt => _autoBlockOnDebt;
  double get tvaRate => _tvaRate;
  bool get kitchenMode => _kitchenMode;

  Future<void> loadSettings() async {
    _debtAlertThreshold = double.tryParse(await _storage.read('debt_alert_threshold') ?? '') ?? 5000;
    _debtBlockThreshold = double.tryParse(await _storage.read('debt_block_threshold') ?? '') ?? 10000;
    _autoBlockOnDebt = (await _storage.read('auto_block_on_debt')) == 'true';
    _tvaRate = double.tryParse(await _storage.read('tva_rate') ?? '') ?? 19;
    
    // Charger kitchenMode depuis le serveur
    try {
      final response = await _apiService.getOrganizationSettings();
      if (response['success']) {
        _kitchenMode = response['data']['kitchenMode'] ?? false;
      }
    } catch (e) {
      // Ignorer l'erreur, garder la valeur par défaut
    }
    
    notifyListeners();
  }

  Future<void> setDebtAlertThreshold(double value) async {
    _debtAlertThreshold = value;
    await _storage.write('debt_alert_threshold', value.toString());
    notifyListeners();
  }

  Future<void> setDebtBlockThreshold(double value) async {
    _debtBlockThreshold = value;
    await _storage.write('debt_block_threshold', value.toString());
    notifyListeners();
  }

  Future<void> setAutoBlockOnDebt(bool value) async {
    _autoBlockOnDebt = value;
    await _storage.write('auto_block_on_debt', value.toString());
    notifyListeners();
  }

  Future<void> setTvaRate(double value) async {
    _tvaRate = value;
    await _storage.write('tva_rate', value.toString());
    notifyListeners();
  }

  Future<bool> setKitchenMode(bool value) async {
    try {
      await _apiService.updateOrganizationSettings({'kitchenMode': value});
      _kitchenMode = value;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
