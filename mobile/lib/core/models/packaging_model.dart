// =====================================================
// MODELS : Gestion des consignes (emballages)
// =====================================================

class PackagingType {
  PackagingType({
    required this.id,
    required this.name,
    required this.depositValue,
    this.organizationId,
    this.description,
    this.active = true,
    this.createdAt,
  });

  factory PackagingType.fromJson(Map<String, dynamic> json) => PackagingType(
        id: json['id'],
        organizationId: json['organizationId'],
        name: json['name'] ?? '',
        description: json['description'],
        depositValue: (json['depositValue'] as num?)?.toDouble() ?? 0,
        active: json['active'] ?? true,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      );
  final String id;
  final String? organizationId;
  final String name;
  final String? description;
  final double depositValue;
  final bool active;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'name': name,
        'description': description,
        'depositValue': depositValue,
        'active': active,
      };
}

class PackagingBalance {
  PackagingBalance({
    required this.packagingTypeId,
    required this.typeName,
    required this.depositValue,
    required this.totalGiven,
    required this.totalReturned,
    required this.outstanding,
  });

  factory PackagingBalance.fromJson(Map<String, dynamic> json) => PackagingBalance(
        packagingTypeId: json['packagingTypeId']?.toString() ?? '',
        typeName: json['typeName']?.toString() ?? '',
        depositValue: (json['depositValue'] as num?)?.toDouble() ?? 0,
        totalGiven: _parseInt(json['totalGiven']),
        totalReturned: _parseInt(json['totalReturned']),
        outstanding: _parseInt(json['outstanding']),
      );
  final String packagingTypeId;
  final String typeName;
  final double depositValue;
  final int totalGiven;
  final int totalReturned;
  final int outstanding;

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double get outstandingValue => outstanding * depositValue;
}

class PackagingTransaction {
  PackagingTransaction({
    required this.id,
    required this.customerId,
    required this.packagingTypeId,
    required this.quantity,
    required this.createdAt,
    this.organizationId,
    this.typeName,
    this.deliveryId,
    this.recordedBy,
    this.recordedByName,
    this.note,
  });

  factory PackagingTransaction.fromJson(Map<String, dynamic> json) => PackagingTransaction(
        id: json['id']?.toString() ?? '',
        organizationId: json['organizationId']?.toString(),
        customerId: json['customerId']?.toString() ?? '',
        packagingTypeId: json['packagingTypeId']?.toString() ?? '',
        typeName: json['typeName']?.toString(),
        deliveryId: json['deliveryId']?.toString(),
        quantity: _parseIntTx(json['quantity']),
        recordedBy: json['recordedBy']?.toString(),
        recordedByName: json['recordedByName']?.toString(),
        note: json['note']?.toString(),
        createdAt: DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      );
  final String id;
  final String? organizationId;
  final String customerId;
  final String packagingTypeId;
  final String? typeName;
  final String? deliveryId;
  final int quantity; // Positive = given, Negative = returned
  final String? recordedBy;
  final String? recordedByName;
  final String? note;
  final DateTime createdAt;

  static int _parseIntTx(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  bool get isGiven => quantity > 0;
  bool get isReturned => quantity < 0;
  int get absoluteQuantity => quantity.abs();
}
