double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class Order {
  final String id;
  final String organizationId;
  final String customerId;
  final String date;
  final double total;
  final String status;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final Cafeteria? cafeteria;
  final String? delivererId;

  Order({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.date,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.amountPaid,
    this.createdAt,
    required this.items,
    this.cafeteria,
    this.delivererId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      total: parseDouble(json['total']),
      status: json['status']?.toString() ?? 'pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'unpaid',
      amountPaid: parseDouble(json['amountPaid']),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      items: json['items'] is List<dynamic>
          ? (json['items'] as List<dynamic>).whereType<Map<String, dynamic>>().map((item) => OrderItem.fromJson(item)).toList()
          : [],
      cafeteria: json['customer'] is Map<String, dynamic> ? Cafeteria.fromJson(json['customer'] as Map<String, dynamic>) : null,
      delivererId: json['delivererId']?.toString(),
    );
  }
  
  /// Empty order for fallback
  factory Order.empty() => Order(
    id: '',
    organizationId: '',
    customerId: '',
    date: '',
    total: 0.0,
    status: 'pending',
    paymentStatus: 'unpaid',
    amountPaid: 0.0,
    items: [],
  );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'customerId': customerId,
      'date': date,
      'total': total,
      'status': status,
      'paymentStatus': paymentStatus,
      'amountPaid': amountPaid,
      'createdAt': createdAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'customer': cafeteria?.toJson(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isLocked => status == 'locked';
  bool get isInDelivery => status == 'in_delivery';
  bool get isDelivered => status == 'delivered';
  bool get isPaid => paymentStatus == 'paid';
  bool get isProblem => status == 'problem';
  double get remainingAmount => total - amountPaid;
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      unitPrice: parseDouble(json['unitPrice']),
      quantity: parseInt(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }

  double get totalPrice => unitPrice * quantity;
}

class Cafeteria {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;

  Cafeteria({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory Cafeteria.fromJson(Map<String, dynamic> json) {
    return Cafeteria(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      latitude: json['latitude'] != null ? parseDouble(json['latitude']) : null,
      longitude: json['longitude'] != null ? parseDouble(json['longitude']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
  
  bool get hasLocation => latitude != null && longitude != null;
}
