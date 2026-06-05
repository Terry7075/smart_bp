/// 商品標準化引擎輸出（Canonical Product）。
final class CanonicalProduct {
  const CanonicalProduct({
    required this.category,
    required this.categoryKey,
    this.categoryId,
    this.brand,
    this.brandId,
    required this.quantity,
    this.unitLabel,
    this.spec,
    this.confidence = 1.0,
    this.matchLayer = 'L0_unknown',
    this.templateOptionId,
    this.pxSearchKeyword,
    this.imageUrl,
    this.needsBrandClarification = false,
  });

  final String category;
  final String categoryKey;
  final String? categoryId;
  final String? brand;
  final String? brandId;
  final int quantity;
  final String? unitLabel;
  final String? spec;
  final double confidence;
  final String matchLayer;
  final String? templateOptionId;
  final String? pxSearchKeyword;
  final String? imageUrl;
  final bool needsBrandClarification;

  Map<String, dynamic> toJson() => {
        'category': category,
        'category_key': categoryKey,
        if (categoryId != null) 'category_id': categoryId,
        if (brand != null) 'brand': brand,
        if (brandId != null) 'brand_id': brandId,
        'quantity': quantity,
        if (unitLabel != null) 'unit_label': unitLabel,
        if (spec != null) 'spec': spec,
        'confidence': confidence,
        'match_layer': matchLayer,
      };

  bool get hasBrand => brand != null && brand!.isNotEmpty && brand != '其他';
}
