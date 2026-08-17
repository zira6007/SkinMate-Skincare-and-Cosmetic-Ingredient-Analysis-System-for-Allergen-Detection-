class ProductModel {

  // ── Fields ────────────────────────────────────────────

  final String  productID;

  final String  brandName;

  final String  productName;

  final String? barcode;

  final String? imageUrl;

  final double  rating;

  final String? categoryTag;

  final String? skinTypeTarget;

  final String? description;

  final bool isActive;

  final String? countryOrigin;

  // ── Constructor ───────────────────────────────────────
  const ProductModel({
    required this.productID,
    required this.brandName,
    required this.productName,
    this.barcode,
    this.imageUrl,
    this.rating        = 0.0,
    this.categoryTag,
    this.skinTypeTarget,
    this.description,
    this.isActive      = true,
    this.countryOrigin,
  });

  // ── fromJson ──────────────────────────────────────────
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productID:      json['productID']           as String? ?? '',
      brandName:      json['brand_name']          as String? ?? '',
      productName:    json['product_name']        as String? ?? '',
      barcode:        json['barcode']             as String?,
      imageUrl:       json['product_image_url']   as String?,
      // rating comes as num from Supabase — convert to double safely
      rating:         (json['avg_rating'] as num? ?? 0).toDouble(),
      categoryTag:    json['category_tag']        as String?,
      skinTypeTarget: json['skin_type_target']    as String?,
      description:    json['product_description'] as String?,
      isActive:       json['is_active']           as bool? ?? true,
      countryOrigin: json['country_origin'] as String?,
    );
  }

  static List<ProductModel> fromJsonList(List<dynamic> list) {
    return list
        .map((row) => ProductModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'productID':           productID,
      'brand_name':          brandName,
      'product_name':        productName,
      'barcode':             barcode,
      'product_image_url':   imageUrl,
      'avg_rating':          rating,
      'category_tag':        categoryTag,
      'skin_type_target':    skinTypeTarget,
      'product_description': description,
      'is_active':           isActive,
      'country_origin': countryOrigin,
    };
  }

  // ── copyWith ──────────────────────────────────────────
  ProductModel copyWith({
    String? imageUrl,
    double? rating,
    bool?   isActive,
    String? description,
  }) {
    return ProductModel(
      productID:      productID,
      brandName:      brandName,
      productName:    productName,
      barcode:        barcode,
      imageUrl:       imageUrl       ?? this.imageUrl,
      rating:         rating         ?? this.rating,
      categoryTag:    categoryTag,
      skinTypeTarget: skinTypeTarget,
      description:    description    ?? this.description,
      isActive:       isActive       ?? this.isActive,
    );
  }

  // ── Computed properties ───────────────────────────────

  String get fullName => '$brandName · $productName';

  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  String toString() =>
      'ProductModel($productID: $brandName $productName)';
}