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
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class Product {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool active;
  final String organizationId;
  final String? category;
  final int sortOrder;
  final bool isNew;
  final bool isPromo;
  final double? promoPrice;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.active,
    required this.organizationId,
    this.category,
    this.sortOrder = 0,
    this.isNew = false,
    this.isPromo = false,
    this.promoPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: parseDouble(json['price']),
      imageUrl: json['image_url']?.toString(),
      active: json['active'] != false,
      organizationId: json['organization_id']?.toString() ?? '',
      category: json['category']?.toString(),
      sortOrder: parseInt(json['sort_order']),
      isNew: json['is_new'] == true,
      isPromo: json['is_promo'] == true,
      promoPrice: json['promo_price'] != null ? parseDouble(json['promo_price']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'active': active,
      'organization_id': organizationId,
      'category': category,
      'sort_order': sortOrder,
      'is_new': isNew,
      'is_promo': isPromo,
      'promo_price': promoPrice,
    };
  }

  // Prix effectif (promo si disponible)
  double get effectivePrice => isPromo && promoPrice != null ? promoPrice! : price;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    bool? active,
    String? organizationId,
    String? category,
    int? sortOrder,
    bool? isNew,
    bool? isPromo,
    double? promoPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      active: active ?? this.active,
      organizationId: organizationId ?? this.organizationId,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      isNew: isNew ?? this.isNew,
      isPromo: isPromo ?? this.isPromo,
      promoPrice: promoPrice ?? this.promoPrice,
    );
  }
}
