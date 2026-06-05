/// Hybrid NLU 統一輸出（規則或 Edge JSON）。
final class ShopNluResult {
  const ShopNluResult({
    required this.confidence,
    required this.source,
    this.intent = 'record_demand',
    this.categoryKey,
    this.categoryLabel,
    this.categoryId,
    this.brandName,
    this.brandId,
    this.productItemId,
    this.spec,
    this.quantity = 1,
    this.unitLabel,
    this.pricePreference,
    this.wantsLastPurchase = false,
    this.missingFields = const [],
    this.rawUtterance,
    this.matchLayer,
  });

  final double confidence;
  final String source;
  final String intent;
  final String? categoryKey;
  final String? categoryLabel;
  final String? categoryId;
  final String? brandName;
  final String? brandId;
  final String? productItemId;
  final String? spec;
  final int quantity;
  final String? unitLabel;

  /// cheap | budget | null
  final String? pricePreference;
  final bool wantsLastPurchase;
  final List<String> missingFields;
  final String? rawUtterance;
  final String? matchLayer;

  bool get needsClarification => missingFields.isNotEmpty;

  bool get isComplete =>
      categoryKey != null &&
      categoryKey != 'unknown' &&
      missingFields.isEmpty &&
      (brandName != null || productItemId != null || pricePreference != null);

  ShopNluResult copyWith({
    double? confidence,
    String? source,
    String? intent,
    List<String>? missingFields,
    String? brandName,
    String? brandId,
    String? productItemId,
    String? spec,
    int? quantity,
    String? pricePreference,
    bool? wantsLastPurchase,
    String? rawUtterance,
  }) {
    return ShopNluResult(
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      intent: intent ?? this.intent,
      categoryKey: categoryKey,
      categoryLabel: categoryLabel,
      categoryId: categoryId,
      brandName: brandName ?? this.brandName,
      brandId: brandId ?? this.brandId,
      productItemId: productItemId ?? this.productItemId,
      spec: spec ?? this.spec,
      quantity: quantity ?? this.quantity,
      unitLabel: unitLabel,
      pricePreference: pricePreference ?? this.pricePreference,
      wantsLastPurchase: wantsLastPurchase ?? this.wantsLastPurchase,
      missingFields: missingFields ?? this.missingFields,
      rawUtterance: rawUtterance ?? this.rawUtterance,
      matchLayer: matchLayer,
    );
  }

  Map<String, dynamic> toJson() => {
        'confidence': confidence,
        'source': source,
        'intent': intent,
        if (categoryKey != null) 'category_key': categoryKey,
        if (categoryLabel != null) 'category_label': categoryLabel,
        if (categoryId != null) 'category_id': categoryId,
        if (brandName != null) 'brand_name': brandName,
        if (brandId != null) 'brand_id': brandId,
        if (productItemId != null) 'product_item_id': productItemId,
        if (spec != null) 'spec': spec,
        'quantity': quantity,
        if (unitLabel != null) 'unit_label': unitLabel,
        if (pricePreference != null) 'price_preference': pricePreference,
        'wants_last_purchase': wantsLastPurchase,
        'missing_fields': missingFields,
        if (rawUtterance != null) 'raw_utterance': rawUtterance,
        if (matchLayer != null) 'match_layer': matchLayer,
      };

  factory ShopNluResult.fromJson(Map<String, dynamic> json) {
    final missing = json['missing_fields'];
    return ShopNluResult(
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      source: json['source']?.toString() ?? 'edge',
      intent: json['intent']?.toString() ?? 'record_demand',
      categoryKey: json['category_key']?.toString(),
      categoryLabel: json['category_label']?.toString(),
      categoryId: json['category_id']?.toString(),
      brandName: json['brand_name']?.toString(),
      brandId: json['brand_id']?.toString(),
      productItemId: json['product_item_id']?.toString(),
      spec: json['spec']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitLabel: json['unit_label']?.toString(),
      pricePreference: json['price_preference']?.toString(),
      wantsLastPurchase: json['wants_last_purchase'] == true,
      missingFields: missing is List
          ? missing.map((e) => e.toString()).toList()
          : const [],
      rawUtterance: json['raw_utterance']?.toString(),
      matchLayer: json['match_layer']?.toString(),
    );
  }
}
