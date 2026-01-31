// =====================================================
// MODELS: Financial Models - Modèles de données financières
// Centralise tous les modèles finance/dette/statistiques
// Version: Sans freezed (pour compatibilité immédiate)
// =====================================================

// ============================================
// ENUMS
// ============================================

enum PaymentStatus { paid, unpaid, partial }

enum PaymentMode { cash, check, transfer }

enum CreditStatus { ok, approaching, overLimit, critical, noLimit }

// ============================================
// FINANCIAL OVERVIEW (Dashboard)
// ============================================

class FinancialOverview {
  final FinancialSummary summary;
  final List<TopClient> topClients;
  final List<DelivererStat> delivererStats;

  FinancialOverview({
    required this.summary,
    this.topClients = const [],
    this.delivererStats = const [],
  });

  factory FinancialOverview.fromJson(Map<String, dynamic> json) {
    return FinancialOverview(
      summary: FinancialSummary.fromJson(json['summary'] ?? {}),
      topClients: (json['topClients'] as List? ?? [])
          .map((e) => TopClient.fromJson(e as Map<String, dynamic>))
          .toList(),
      delivererStats: (json['delivererStats'] as List? ?? [])
          .map((e) => DelivererStat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FinancialSummary {
  final double totalRevenue;
  final double totalCollected;
  final double totalUnpaid;
  final int totalOrders;
  final int deliveredOrders;
  final int paidOrders;
  final int unpaidOrders;
  final int partialOrders;
  final int totalCustomers;
  final int customersWithDebt;

  FinancialSummary({
    this.totalRevenue = 0,
    this.totalCollected = 0,
    this.totalUnpaid = 0,
    this.totalOrders = 0,
    this.deliveredOrders = 0,
    this.paidOrders = 0,
    this.unpaidOrders = 0,
    this.partialOrders = 0,
    this.totalCustomers = 0,
    this.customersWithDebt = 0,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0,
      totalUnpaid: (json['totalUnpaid'] as num?)?.toDouble() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (json['deliveredOrders'] as num?)?.toInt() ?? 0,
      paidOrders: (json['paidOrders'] as num?)?.toInt() ?? 0,
      unpaidOrders: (json['unpaidOrders'] as num?)?.toInt() ?? 0,
      partialOrders: (json['partialOrders'] as num?)?.toInt() ?? 0,
      totalCustomers: (json['totalCustomers'] as num?)?.toInt() ?? 0,
      customersWithDebt: (json['customersWithDebt'] as num?)?.toInt() ?? 0,
    );
  }

  double get collectionRate => totalRevenue > 0 ? (totalCollected / totalRevenue) : 0;
  double get debtRate => totalRevenue > 0 ? (totalUnpaid / totalRevenue) : 0;
}

class TopClient {
  final String id;
  final String name;
  final String? phone;
  final double totalRevenue;
  final double totalPaid;
  final double totalDebt;
  final int orderCount;

  TopClient({
    required this.id,
    required this.name,
    this.phone,
    this.totalRevenue = 0,
    this.totalPaid = 0,
    this.totalDebt = 0,
    this.orderCount = 0,
  });

  factory TopClient.fromJson(Map<String, dynamic> json) {
    return TopClient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DelivererStat {
  final String id;
  final String name;
  final int totalDeliveries;
  final int deliveredCount;
  final double amountCollected;

  DelivererStat({
    required this.id,
    required this.name,
    this.totalDeliveries = 0,
    this.deliveredCount = 0,
    this.amountCollected = 0,
  });

  factory DelivererStat.fromJson(Map<String, dynamic> json) {
    return DelivererStat(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['deliveredCount'] as num?)?.toInt() ?? 0,
      amountCollected: (json['amountCollected'] as num?)?.toDouble() ?? 0,
    );
  }

  double get successRate => totalDeliveries > 0 ? (deliveredCount / totalDeliveries) : 0;
}

// ============================================
// DEBT MANAGEMENT
// ============================================

class CustomerDebt {
  final String customerId;
  final String name;
  final String? email;
  final String? phone;
  final double totalDebt;
  final int unpaidOrders;
  final double creditLimit;
  final CreditInfo? credit;
  final List<UnpaidOrder> orders;
  final DateTime? lastOrderDate;

  CustomerDebt({
    required this.customerId,
    required this.name,
    this.email,
    this.phone,
    this.totalDebt = 0,
    this.unpaidOrders = 0,
    this.creditLimit = 0,
    this.credit,
    this.orders = const [],
    this.lastOrderDate,
  });

  factory CustomerDebt.fromJson(Map<String, dynamic> json) {
    return CustomerDebt(
      customerId: json['customerId'] as String? ?? json['customer_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 
                 (json['total_debt'] as num?)?.toDouble() ?? 0,
      unpaidOrders: (json['unpaidOrders'] as num?)?.toInt() ?? 
                    (json['unpaid_orders'] as num?)?.toInt() ?? 0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 
                   (json['credit_limit'] as num?)?.toDouble() ?? 0,
      credit: json['credit'] != null 
          ? CreditInfo.fromJson(json['credit'] as Map<String, dynamic>)
          : null,
      orders: (json['unpaidOrders'] as List? ?? [])
          .map((e) => UnpaidOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastOrderDate: json['lastOrderDate'] != null 
          ? DateTime.tryParse(json['lastOrderDate'].toString())
          : null,
    );
  }

  bool get hasDebt => totalDebt > 0;
  bool get hasCreditLimit => creditLimit > 0;
  double get availableCredit => credit?.available ?? 0;
}

class CreditInfo {
  final double limit;
  final double used;
  final double available;
  final int ratio;
  final CreditStatus status;
  final String? level;

  CreditInfo({
    this.limit = 0,
    this.used = 0,
    this.available = 0,
    this.ratio = 0,
    this.status = CreditStatus.noLimit,
    this.level,
  });

  factory CreditInfo.fromJson(Map<String, dynamic> json) {
    String? statusStr = json['status'] as String?;
    CreditStatus status = CreditStatus.noLimit;
    if (statusStr == 'critical') status = CreditStatus.critical;
    else if (statusStr == 'over_limit') status = CreditStatus.overLimit;
    else if (statusStr == 'approaching') status = CreditStatus.approaching;
    else if (statusStr == 'ok') status = CreditStatus.ok;

    return CreditInfo(
      limit: (json['limit'] as num?)?.toDouble() ?? 0,
      used: (json['used'] as num?)?.toDouble() ?? 0,
      available: (json['available'] as num?)?.toDouble() ?? 0,
      ratio: (json['ratio'] as num?)?.toInt() ?? 0,
      status: status,
      level: json['level'] as String?,
    );
  }

  bool get isCritical => status == CreditStatus.critical;
  bool get isOverLimit => status == CreditStatus.overLimit;
  bool get isApproaching => status == CreditStatus.approaching;
}

class UnpaidOrder {
  final String id;
  final String? orderNumber;
  final DateTime? date;
  final double total;
  final double amountPaid;
  final double remaining;
  final String status;
  final PaymentStatus paymentStatus;

  UnpaidOrder({
    required this.id,
    this.orderNumber,
    this.date,
    this.total = 0,
    this.amountPaid = 0,
    this.remaining = 0,
    this.status = 'pending',
    this.paymentStatus = PaymentStatus.unpaid,
  });

  factory UnpaidOrder.fromJson(Map<String, dynamic> json) {
    PaymentStatus ps = PaymentStatus.unpaid;
    String? psStr = json['paymentStatus'] as String? ?? json['payment_status'] as String?;
    if (psStr == 'paid') ps = PaymentStatus.paid;
    else if (psStr == 'partial') ps = PaymentStatus.partial;

    return UnpaidOrder(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? json['order_number'] as String?,
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 
                  (json['amount_paid'] as num?)?.toDouble() ?? 0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      paymentStatus: ps,
    );
  }

  double get progress => total > 0 ? (amountPaid / total) : 0;
  bool get isFullyPaid => remaining <= 0;
}

// ============================================
// PAYMENTS
// ============================================

class Payment {
  final String id;
  final String customerId;
  final String? customerName;
  final double amount;
  final PaymentMode mode;
  final String? notes;
  final DateTime createdAt;
  final List<PaymentOrderAllocation> orders;

  Payment({
    required this.id,
    required this.customerId,
    this.customerName,
    this.amount = 0,
    this.mode = PaymentMode.cash,
    this.notes,
    required this.createdAt,
    this.orders = const [],
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    PaymentMode mode = PaymentMode.cash;
    String? modeStr = json['mode'] as String?;
    if (modeStr == 'check') mode = PaymentMode.check;
    else if (modeStr == 'transfer') mode = PaymentMode.transfer;

    return Payment(
      id: json['id'] as String? ?? json['paymentId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? json['customer_id'] as String? ?? '',
      customerName: json['customerName'] as String? ?? json['customer_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      mode: mode,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      orders: (json['ordersAffected'] as List? ?? [])
          .map((e) => PaymentOrderAllocation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaymentOrderAllocation {
  final String orderId;
  final double amountApplied;
  final PaymentStatus? newStatus;

  PaymentOrderAllocation({
    required this.orderId,
    this.amountApplied = 0,
    this.newStatus,
  });

  factory PaymentOrderAllocation.fromJson(Map<String, dynamic> json) {
    PaymentStatus? ps;
    String? psStr = json['newStatus'] as String? ?? json['new_status'] as String?;
    if (psStr == 'paid') ps = PaymentStatus.paid;
    else if (psStr == 'partial') ps = PaymentStatus.partial;

    return PaymentOrderAllocation(
      orderId: json['orderId'] as String? ?? json['order_id'] as String? ?? '',
      amountApplied: (json['amountApplied'] as num?)?.toDouble() ?? 
                     (json['amount_applied'] as num?)?.toDouble() ?? 0,
      newStatus: ps,
    );
  }
}

// ============================================
// CREDIT ALERTS
// ============================================

class CreditAlert {
  final CustomerSummary customer;
  final CreditInfo credit;

  CreditAlert({
    required this.customer,
    required this.credit,
  });

  factory CreditAlert.fromJson(Map<String, dynamic> json) {
    return CreditAlert(
      customer: CustomerSummary.fromJson(json['customer'] as Map<String, dynamic>),
      credit: CreditInfo.fromJson(json['credit'] as Map<String, dynamic>),
    );
  }
}

class CustomerSummary {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  CustomerSummary({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

// ============================================
// PAGINATION
// ============================================

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    this.page = 1,
    this.limit = 50,
    this.total = 0,
    this.totalPages = 0,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

class PaginatedDebts {
  final List<CustomerDebt> data;
  final PaginationInfo pagination;

  PaginatedDebts({
    this.data = const [],
    required this.pagination,
  });

  factory PaginatedDebts.fromJson(Map<String, dynamic> json) {
    return PaginatedDebts(
      data: (json['data'] as List? ?? [])
          .map((e) => CustomerDebt.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}

// ============================================
// STATS & REPORTS
// ============================================

class DailyStats {
  final DateTime date;
  final int orderCount;
  final double totalRevenue;
  final double totalCollected;
  final double totalDebt;

  DailyStats({
    required this.date,
    this.orderCount = 0,
    this.totalRevenue = 0,
    this.totalCollected = 0,
    this.totalDebt = 0,
  });

  double get collectionRate => totalRevenue > 0 ? (totalCollected / totalRevenue) : 0;
}

class PeriodStats {
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double totalCA;
  final double collected;
  final double unpaid;
  final int orderCount;
  final int pending;
  final int delivered;

  PeriodStats({
    required this.period,
    required this.startDate,
    required this.endDate,
    this.totalCA = 0,
    this.collected = 0,
    this.unpaid = 0,
    this.orderCount = 0,
    this.pending = 0,
    this.delivered = 0,
  });

  double get collectionRate => totalCA > 0 ? (collected / totalCA) : 0;
  double get averageOrderValue => orderCount > 0 ? (totalCA / orderCount) : 0;
}

// ============================================
// HELPERS
// ============================================

class FinancialHelpers {
  /// Calcule le statut de crédit basé sur le ratio
  static CreditStatus calculateCreditStatus(double debt, double limit) {
    if (limit <= 0) return CreditStatus.noLimit;
    
    final ratio = (debt / limit) * 100;
    
    if (ratio >= 120) return CreditStatus.critical;
    if (ratio >= 100) return CreditStatus.overLimit;
    if (ratio >= 80) return CreditStatus.approaching;
    return CreditStatus.ok;
  }

  /// Formate un montant en DA
  static String formatCurrency(double amount, {int decimals = 0}) {
    return '${amount.toStringAsFixed(decimals)} DA';
  }
}
