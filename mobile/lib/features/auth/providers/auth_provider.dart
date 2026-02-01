import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorage _storage = SecureStorage();

  Map<String, dynamic>? _user;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  void setUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.login(email, password);
      
      if (response['success'] == true) {
        // Nouveau format: accessToken au lieu de token
        final token = response['accessToken'] ?? response['token'];
        final userData = response['user'];
        
        await _storage.saveToken(token.toString());
        await _storage.saveUser(userData as Map<String, dynamic>);
        
        // Sauvegarder le refresh token si présent
        if (response['refreshToken'] != null) {
          await _storage.saveRefreshToken(response['refreshToken'].toString());
        }
        
        _user = userData;
        _isLoading = false;
        
        // Connecter OneSignal
        if (userData['id'] != null) {
          NotificationService().login(userData['id'].toString());
        }
        
        notifyListeners();
        return true;
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      // Ignorer les erreurs de logout API
    }
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  Future<void> logoutAllDevices() async {
    try {
      await _apiService.logoutAllDevices();
    } catch (e) {
      // Ignorer les erreurs
    }
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  Future<bool> refreshUser() async {
    try {
      final response = await _apiService.getMe();
      if (response['success'] == true) {
        final userData = response['user'];
        await _storage.saveUser(userData as Map<String, dynamic>);
        _user = userData;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      await logout();
      return false;
    }
  }
}