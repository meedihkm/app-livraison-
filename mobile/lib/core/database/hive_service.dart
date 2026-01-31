import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();
  HiveService.forTesting();

  static const String boxAuth = 'auth';
  static const String boxData = 'data';
  static const String boxSync = 'sync_queue';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Ouvrir les boîtes
    await Hive.openBox(boxAuth);
    await Hive.openBox(boxData);
    await Hive.openBox(boxSync);
  }

  // Generic Data Cache (storing API responses)
  Future<void> cacheData(String key, dynamic data) async {
    final box = Hive.box(boxData);
    await box.put(key, {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  dynamic getCachedData(String key) {
    final box = Hive.box(boxData);
    final entry = box.get(key);
    if (entry != null) {
      return entry['data'];
    }
    return null;
  }

  // Sync Queue (Offline Actions)
  Future<void> addOfflineAction(String type, Map<String, dynamic> payload) async {
    final box = Hive.box(boxSync);
    final action = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await box.add(action);
  }

  List<Map<String, dynamic>> getPendingActions() {
    final box = Hive.box(boxSync);
    return box.values.cast<Map<String, dynamic>>().toList();
  }
  
  Map<dynamic, Map<dynamic, dynamic>> getPendingActionsMap() {
    final box = Hive.box(boxSync);
    return box.toMap().cast<dynamic, Map<dynamic, dynamic>>();
  }

  Future<int> getPendingActionsCount() async {
    final box = Hive.box(boxSync);
    return box.length;
  }

  Future<void> removeAction(int index) async {
    final box = Hive.box(boxSync);
    await box.deleteAt(index);
  }
  
  Future<void> deleteActionByKey(dynamic key) async {
    final box = Hive.box(boxSync);
    await box.delete(key);
  }

  Future<void> updateAction(dynamic key, Map<String, dynamic> action) async {
    final box = Hive.box(boxSync);
    await box.put(key, action);
  }

  Future<void> clearAllData() async {
    await Hive.box(boxData).clear();
    await Hive.box(boxSync).clear();
    // Don't clear auth usually
  }
}
