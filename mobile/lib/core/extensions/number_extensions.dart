// =====================================================
// EXTENSIONS: Parsing de nombres sécurisé
// Élimine la duplication de _parseDouble dans tous les fichiers
// =====================================================

/// Extensions pour parser les nombres depuis n'importe quel type
extension DynamicNumberParsing on dynamic {
  /// Convertit en double, retourne 0 si invalide
  /// 
  /// Usage: `value.toDoubleOrZero()` au lieu de `_parseDouble(value)`
  double toDoubleOrZero() {
    if (this == null) return 0.0;
    if (this is double) return this as double;
    if (this is int) return (this as int).toDouble();
    if (this is String) {
      final parsed = double.tryParse(this as String);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  /// Convertit en double nullable (null si invalide)
  double? toDoubleOrNull() {
    if (this == null) return null;
    if (this is double) return this as double;
    if (this is int) return (this as int).toDouble();
    if (this is String) {
      return double.tryParse(this as String);
    }
    return null;
  }

  /// Convertit en int, retourne 0 si invalide
  int toIntOrZero() {
    if (this == null) return 0;
    if (this is int) return this as int;
    if (this is double) return (this as double).toInt();
    if (this is String) {
      final parsed = int.tryParse(this as String);
      return parsed ?? 0;
    }
    return 0;
  }

  /// Convertit en booléen depuis divers formats
  bool toBool() {
    if (this == null) return false;
    if (this is bool) return this as bool;
    if (this is int) return (this as int) != 0;
    if (this is String) {
      final str = (this as String).toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }
    return false;
  }
}

/// Extensions pour les List<dynamic> (JSON arrays)
extension DynamicListParsing on List<dynamic>? {
  /// Mappe une liste dynamique en liste typée avec gestion d'erreur
  /// 
  /// Usage:
  /// ```dart
  /// final debts = json['debts'].mapList((e) => CustomerDebt.fromJson(e));
  /// ```
  List<T> mapList<T>(T Function(Map<String, dynamic>) converter) {
    if (this == null) return [];
    return this!
        .whereType<Map<String, dynamic>>()
        .map(converter)
        .toList();
  }

  /// Filtre et mappe avec index
  List<T> mapIndexed<T>(T Function(int index, Map<String, dynamic>) converter) {
    if (this == null) return [];
    return this!
        .asMap()
        .entries
        .where((e) => e.value is Map<String, dynamic>)
        .map((e) => converter(e.key, e.value as Map<String, dynamic>))
        .toList();
  }
}

/// Extensions pour les Map<String, dynamic> (JSON objects)
extension JsonParsing on Map<String, dynamic> {
  /// Récupère une valeur double d'un champ JSON
  double getDouble(String key, {double defaultValue = 0.0}) {
    return this[key].toDoubleOrZero();
  }

  /// Récupère une valeur int d'un champ JSON
  int getInt(String key, {int defaultValue = 0}) {
    return this[key].toIntOrZero();
  }

  /// Récupère une valeur String d'un champ JSON
  String getString(String key, {String defaultValue = ''}) {
    final value = this[key];
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// Récupère une valeur booléenne d'un champ JSON
  bool getBool(String key, {bool defaultValue = false}) {
    final value = this[key];
    if (value == null) return defaultValue;
    return value.toBool();
  }

  /// Récupère une date depuis un champ ISO8601
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Récupère une liste d'objets JSON
  List<Map<String, dynamic>> getList(String key) {
    final value = this[key];
    if (value == null) return [];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}

/// Extensions pour le formatage des nombres
extension NumberFormatting on double {
  /// Formate comme montant en DA (Dinar Algérien)
  String toCurrency({String symbol = 'DA', int decimals = 0}) {
    final formatter = '${toStringAsFixed(decimals)} $symbol';
    return formatter;
  }

  /// Formate comme pourcentage
  String toPercent({int decimals = 1}) {
    return '${toStringAsFixed(decimals)}%';
  }

  /// Arrondi intelligent (pas de décimales si entier)
  String formatSmart() {
    if (this == roundToDouble()) {
      return toInt().toString();
    }
    return toStringAsFixed(2);
  }
}

/// Extensions pour les calculs financiers
extension FinancialCalculations on List<Map<String, dynamic>> {
  /// Calcule la somme d'un champ sur une liste d'objets
  double sumOf(String field) {
    return fold(0.0, (sum, item) => sum + item.getDouble(field));
  }

  /// Calcule la moyenne d'un champ
  double averageOf(String field) {
    if (isEmpty) return 0.0;
    return sumOf(field) / length;
  }

  /// Filtre les éléments où un champ est supérieur à une valeur
  List<Map<String, dynamic>> whereGreaterThan(String field, double value) {
    return where((item) => item.getDouble(field) > value).toList();
  }
}
