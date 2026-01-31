class FavoriteOrder {
  final String id;
  final String name;
  final List<FavoriteOrderItem> items;
  final double total;
  final int orderCount;
  final DateTime? lastOrderedAt;
  final bool isAutoDetected;
  final DateTime createdAt;

  FavoriteOrder({
    required this.id,
    required this.name,
    required this.items,
    required this.total,
    required this.orderCount,
    this.lastOrderedAt,
    required this.isAutoDetected,
    required this.createdAt,
  });

  factory FavoriteOrder.fromJson(Map<String, dynamic> json) {
    return FavoriteOrder(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Favori',
      items: (json['items'] as List?)
              ?.map((item) => FavoriteOrderItem.fromJson(item))
              .toList() ??
          [],
      total: _parseDouble(json['total']),
      orderCount: json['order_count'] ?? 0,
      lastOrderedAt: json['last_ordered_at'] != null
          ? DateTime.tryParse(json['last_ordered_at'])
          : null,
      isAutoDetected: json['is_auto_detected'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'order_count': orderCount,
      'last_ordered_at': lastOrderedAt?.toIso8601String(),
      'is_auto_detected': isAutoDetected,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class FavoriteOrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  FavoriteOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  factory FavoriteOrderItem.fromJson(Map<String, dynamic> json) {
    return FavoriteOrderItem(
      productId: json['productId'] ?? json['product_id'] ?? '',
      productName: json['productName'] ?? json['product_name'] ?? 'Produit',
      quantity: json['quantity'] ?? 0,
      unitPrice: _parseDouble(json['unitPrice'] ?? json['unit_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class UserPreferences {
  final bool favoriteOrdersEnabled;
  final bool autoSuggestEnabled;
  final int minPatternCount;

  UserPreferences({
    required this.favoriteOrdersEnabled,
    required this.autoSuggestEnabled,
    required this.minPatternCount,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      favoriteOrdersEnabled: json['favorite_orders_enabled'] ?? true,
      autoSuggestEnabled: json['auto_suggest_enabled'] ?? true,
      minPatternCount: json['min_pattern_count'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'favorite_orders_enabled': favoriteOrdersEnabled,
      'auto_suggest_enabled': autoSuggestEnabled,
      'min_pattern_count': minPatternCount,
    };
  }
}
