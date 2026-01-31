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
    id: json['id'],
    organizationId: json['organizationId'],
    cafeteriaId: json['cafeteriaId'],
    cafeteriaName: json['cafeteriaName'],
    name: json['name'],
    frequency: json['frequency'] ?? 'weekly',
    dayOfWeek: json['dayOfWeek'],
    dayOfMonth: json['dayOfMonth'],
    timeOfDay: json['timeOfDay'] ?? '06:00:00',
    active: json['active'] ?? true,
    lastGeneratedAt: json['lastGeneratedAt'] != null 
      ? DateTime.tryParse(json['lastGeneratedAt'].toString()) 
      : null,
    nextGenerationAt: json['nextGenerationAt'] != null 
      ? DateTime.tryParse(json['nextGenerationAt'].toString()) 
      : null,
    createdAt: DateTime.parse(json['createdAt']),
    items: (json['items'] as List? ?? [])
        .map((e) => RecurringOrderItem.fromJson(e))
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
    id: json['id'],
    productId: json['productId'],
    productName: json['productName'],
    quantity: json['quantity'] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}
