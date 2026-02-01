import 'order_model.dart';

double parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0;
}

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

class Delivery {
  Delivery({
    required this.id,
    required this.orderId,
    required this.status,
    required this.paymentStatus,
    required this.amountCollected,
    required this.order,
    this.delivererId,
    this.comment,
    this.failureReason,
    this.deliveredAt,
    this.failedAt,
    this.postponedTo,
    this.attempts = 0,
    this.createdAt,
    this.deliverer,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      delivererId: json['delivererId']?.toString(),
      status: json['status']?.toString() ?? 'assigned',
      paymentStatus: json['paymentStatus']?.toString() ?? 'unpaid',
      amountCollected: parseDouble(json['amountCollected']),
      comment: json['comment']?.toString(),
      failureReason: json['failureReason']?.toString(),
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt'].toString()) : null,
      failedAt: json['failedAt'] != null ? DateTime.tryParse(json['failedAt'].toString()) : null,
      postponedTo: json['postponedTo'] != null ? DateTime.tryParse(json['postponedTo'].toString()) : null,
      attempts: parseInt(json['attempts']),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      order: json['order'] is Map<String, dynamic> 
          ? Order.fromJson(json['order'] as Map<String, dynamic>)
          : Order.empty(),
      deliverer: json['deliverer'] is Map<String, dynamic> 
          ? Deliverer.fromJson(json['deliverer'] as Map<String, dynamic>) 
          : null,
    );
  }
  final String id;
  final String orderId;
  final String? delivererId;
  final String status;
  final String paymentStatus;
  final double amountCollected;
  final String? comment;
  final String? failureReason;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final DateTime? postponedTo;
  final int attempts;
  final DateTime? createdAt;
  final Order order;
  final Deliverer? deliverer;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'delivererId': delivererId,
      'status': status,
      'paymentStatus': paymentStatus,
      'amountCollected': amountCollected,
      'comment': comment,
      'failureReason': failureReason,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'failedAt': failedAt?.toIso8601String(),
      'postponedTo': postponedTo?.toIso8601String(),
      'attempts': attempts,
      'createdAt': createdAt?.toIso8601String(),
      'order': order.toJson(),
      'deliverer': deliverer?.toJson(),
    };
  }

  bool get isAssigned => status == 'assigned';
  bool get isInProgress => status == 'in_progress';
  bool get isDelivered => status == 'delivered';
  bool get isFailed => status == 'failed';
  bool get isPostponed => status == 'postponed';
  bool get isPaid => paymentStatus == 'paid';

  String get failureReasonText {
    switch (failureReason) {
      case 'closed':
        return 'Client fermé';
      case 'absent':
        return 'Client absent';
      case 'address_not_found':
        return 'Adresse introuvable';
      case 'refused':
        return 'Commande refusée';
      case 'other':
        return 'Autre raison';
      default:
        return failureReason ?? '';
    }
  }
}

class Deliverer {
  Deliverer({required this.id, required this.name, this.phone});

  factory Deliverer.fromJson(Map<String, dynamic> json) {
    return Deliverer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }
  final String id;
  final String name;
  final String? phone;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};
}
