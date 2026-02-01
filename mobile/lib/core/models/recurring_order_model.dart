// =====================================================
// MODELS : Commandes Récurrentes
// =====================================================

class RecurringOrder {
  final String id;
  final String? organizationId;
  final String cafeteriaId;
  final String? cafeteriaName;
  final String? name;
  final String frequency;  // 'daily', 'weekly', 'monthly'
  final int? dayOfWeek;    // 0-6 (Sunday-Saturday)
  final int? dayOfMonth;   // 1-31
  final String timeOfDay;
  final bool active;
  final DateTime? lastGeneratedAt;
  final DateTime? nextGenerationAt;
  final DateTime createdAt;
  final List<RecurringOrderItem> items;

  RecurringOrder({
    required this.id,
    this.organizationId,
    required this.cafeteriaId,
    this.cafeteriaName,
    this.name,
    required this.frequency,
    this.dayOfWeek,
    this.dayOfMonth,
    required this.timeOfDay,
    required this.active,
    this.lastGeneratedAt,
    this.nextGenerationAt,
    required this.createdAt,
    required this.items,
  });

  factory RecurringOrder.fromJson(Map<String, dynamic> json) => RecurringOrder(
    id: json['id']?.toString() ?? '',
    organizationId: json['organizationId']?.toString(),
    cafeteriaId: json['cafeteriaId']?.toString() ?? '',
    cafeteriaName: json['cafeteriaName']?.toString(),
    name: json['name']?.toString(),
    frequency: json['frequency']?.toString() ?? 'weekly',
    dayOfWeek: (json['dayOfWeek'] as num?)?.toInt(),
    dayOfMonth: (json['dayOfMonth'] as num?)?.toInt(),
    timeOfDay: json['timeOfDay']?.toString() ?? '06:00:00',
    active: json['active'] != false,
    lastGeneratedAt: json['lastGeneratedAt'] != null 
      ? DateTime.tryParse(json['lastGeneratedAt'].toString()) 
      : null,
    nextGenerationAt: json['nextGenerationAt'] != null 
      ? DateTime.tryParse(json['nextGenerationAt'].toString()) 
      : null,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    items: (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RecurringOrderItem.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'frequency': frequency,
    'dayOfWeek': dayOfWeek,
    'dayOfMonth': dayOfMonth,
    'timeOfDay': timeOfDay,
    'items': items.map((e) => e.toJson()).toList(),
  };

  String get frequencyLabel {
    switch (frequency) {
      case 'daily': return 'Quotidien';
      case 'weekly': return 'Hebdomadaire';
      case 'monthly': return 'Mensuel';
      default: return frequency;
    }
  }

  String? get scheduleSummary {
    switch (frequency) {
      case 'daily':
        return 'Tous les jours à ${_formatTime(timeOfDay)}';
      case 'weekly':
        if (dayOfWeek != null) {
          return 'Chaque ${_dayName(dayOfWeek!)} à ${_formatTime(timeOfDay)}';
        }
        return 'Hebdomadaire à ${_formatTime(timeOfDay)}';
      case 'monthly':
        if (dayOfMonth != null) {
          return 'Le $dayOfMonth de chaque mois à ${_formatTime(timeOfDay)}';
        }
        return 'Mensuel à ${_formatTime(timeOfDay)}';
      default:
        return null;
    }
  }

  static String _dayName(int day) {
    const days = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    return days[day % 7];
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}h${parts[1]}';
    }
    return time;
  }
}

class RecurringOrderItem {
  final String? id;
  final String productId;
  final String? productName;
  final int quantity;

  RecurringOrderItem({
    this.id,
    required this.productId,
    this.productName,
    required this.quantity,
  });

  factory RecurringOrderItem.fromJson(Map<String, dynamic> json) => RecurringOrderItem(
    id: json['id']?.toString(),
    productId: json['productId']?.toString() ?? '',
    productName: json['productName']?.toString(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}
