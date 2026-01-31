// =====================================================
// MODELS : Gestion de la dette
// =====================================================

class CustomerDebt {
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final double totalDebt;
  final int unpaidOrders;
  final DateTime? lastOrderDate;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;

  CustomerDebt({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.totalDebt,
    required this.unpaidOrders,
    this.lastOrderDate,
    this.lastPaymentDate,
    this.lastPaymentAmount,
  });

  factory CustomerDebt.fromJson(Map<String, dynamic> json) => CustomerDebt(
    customerId: json['customer_id'],
    customerName: json['customer_name'] ?? json['name'] ?? '',
    customerPhone: json['customer_phone'] ?? json['phone'],
    totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0,
    unpaidOrders: json['unpaid_orders'] ?? 0,
    lastOrderDate: json['last_order_date'] != null 
      ? DateTime.tryParse(json['last_order_date'].toString()) 
      : null,
    lastPaymentDate: json['last_payment_date'] != null 
      ? DateTime.tryParse(json['last_payment_date'].toString()) 
      : null,
    lastPaymentAmount: (json['last_payment_amount'] as num?)?.toDouble(),
  );

  bool get hasDebt => totalDebt > 0;
}

class DebtPayment {
  final String id;
  final String customerId;
  final String? customerName;
  final double amount;
  final String paymentType;
  final String collectedBy;
  final String? collectorName;
  final String collectorRole;
  final String? deliveryId;
  final String? note;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.amount,
    required this.paymentType,
    required this.collectedBy,
    this.collectorName,
    required this.collectorRole,
    this.deliveryId,
    this.note,
    required this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) => DebtPayment(
    id: json['id'],
    customerId: json['customer_id'],
    customerName: json['customer_name'],
    amount: (json['amount'] as num).toDouble(),
    paymentType: json['payment_type'],
    collectedBy: json['collected_by'],
    collectorName: json['collector_name'],
    collectorRole: json['collector_role'],
    deliveryId: json['delivery_id'],
    note: json['note'],
    createdAt: DateTime.parse(json['created_at']),
  );
}
