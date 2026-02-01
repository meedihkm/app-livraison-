class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String organizationId;
  final Organization organization;
  final String? phone;
  final double? creditLimit;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.organizationId,
    required this.organization,
    this.phone,
    this.creditLimit,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      organization: json['organization'] is Map<String, dynamic>
          ? Organization.fromJson(json['organization'] as Map<String, dynamic>)
          : Organization(id: '', name: '', type: ''),
      phone: json['phone']?.toString(),
      creditLimit: (json['credit_limit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'organizationId': organizationId,
      'organization': organization.toJson(),
      'phone': phone,
      'credit_limit': creditLimit,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isCafeteria => role == 'customer';
  bool get isDeliverer => role == 'deliverer';
}

class Organization {
  final String id;
  final String name;
  final String type;

  Organization({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
    };
  }
}
