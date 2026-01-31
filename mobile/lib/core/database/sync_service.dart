import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../services/api_service.dart';
import 'hive_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  HiveService _hiveService = HiveService();
  ApiService _apiService = ApiService();
  
  @visibleForTesting
  set apiService(ApiService service) => _apiService = service;
  
  @visibleForTesting
  set hiveService(HiveService service) => _hiveService = service;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  @visibleForTesting
  set isOnline(bool value) => _isOnline = value;
  
  StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  StreamController<int> _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingActionCount => _pendingCountController.stream;

  Future<void> init() async {
    // Initial check
    _isOnline = await InternetConnectionChecker.instance.hasConnection;
    _connectionStatusController.add(_isOnline);
    _updatePendingCount();

    // Listen to changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      bool hasConnection = false;
      if (!results.contains(ConnectivityResult.none)) {
        hasConnection = await InternetConnectionChecker.instance.hasConnection;
      }
      
      if (_isOnline != hasConnection) {
        _isOnline = hasConnection;
        _connectionStatusController.add(_isOnline);
        
        if (_isOnline) {
          _processQueue(); // Sync when back online
        }
      }
    });

    if (_isOnline) {
      _processQueue();
    }
  }

  Future<void> _updatePendingCount() async {
    final count = await _hiveService.getPendingActionsCount();
    _pendingCountController.add(count);
  }

  Future<void> addOfflineAction(String type, Map<String, dynamic> payload) async {
    await _hiveService.addOfflineAction(type, payload);
    _updatePendingCount();
    if (_isOnline) {
      await _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (!_isOnline) return;

    final pending = _hiveService.getPendingActionsMap();
    if (pending.isEmpty) {
       _updatePendingCount();
       return;
    }

    // Sort by key to ensure order
    final sortedKeys = pending.keys.toList()..sort();
    
    print('SyncService: Processing ${sortedKeys.length} pending actions...');

    for (var key in sortedKeys) {
      if (!_isOnline) break;

      final action = pending[key]!;
      
      // Skip actions marked for review (conflicts)
      if (action['status'] == 'needs_review') continue;

      final type = action['type'];
      final payload = Map<String, dynamic>.from(action['payload'] as Map);

      try {
        switch (type) {
          case 'CREATE_ORDER':
            await _apiService.createOrder(payload);
            break;
          case 'UPDATE_DELIVERY':
            final deliveryId = payload['deliveryId'];
            payload.remove('deliveryId');
            await _apiService.updateDeliveryStatus(deliveryId, payload);
            break;
          default:
            print('Unknown action type: $type');
        }
        
        // Success
        await _hiveService.deleteActionByKey(key);
        _updatePendingCount();
        
      } on ApiException catch (e) {
        print('Sync ApiException for $key: ${e.statusCode}');
        
        if (e.statusCode == 404) {
          // Resource deleted on server -> Remove action
          await _hiveService.deleteActionByKey(key);
          _updatePendingCount();
        } else if (e.statusCode == 409) {
          // Conflict -> Mark for review
          action['status'] = 'needs_review';
          await _hiveService.updateAction(key, action.cast<String, dynamic>());
          // Don't delete, keep for review
        }
        // Other errors (500): retry later (keep in queue)
      } catch (e) {
        print('Sync Error for $key: $e');
        // Likely network error or code error, keep in queue
      }
    }
  }

  // Called to start manual sync or refresh
  Future<void> syncData() async {
    if (_isOnline) {
      await _processQueue();
    }
  }
}
