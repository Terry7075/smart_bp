bool _isUuid(String? s) {
  if (s == null || s.isEmpty) return false;
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(s);
}

/// 代購明細寫入 DB 時的結構化快照（志工採買、後台統計）。
final class SupplyLineSnapshot {
  const SupplyLineSnapshot({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unitPrice,
    this.brand,
    this.spec,
    this.unitLabel,
    this.category,
    this.supplyCategoryKey,
    this.templateOptionId,
    this.pxProductId,
    this.sourceUrl,
    this.pxSearchKeyword,
    this.imageUrl,
    this.referenceNote,
    this.categoryId,
    this.brandId,
    this.productItemId,
    this.normalizeConfidence,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double? unitPrice;
  final String? brand;
  final String? spec;
  final String? unitLabel;
  final String? category;
  final String? supplyCategoryKey;
  final String? templateOptionId;
  final String? pxProductId;
  final String? sourceUrl;
  final String? pxSearchKeyword;
  final String? imageUrl;
  final String? referenceNote;
  final String? categoryId;
  final String? brandId;
  final String? productItemId;
  final double? normalizeConfidence;

  /// 從 `product_id`（如 `item:<uuid>`）或欄位解析標準品項 UUID。
  static String? parseProductItemId(String? productId, {String? explicit}) {
    if (_isUuid(explicit)) return explicit;
    if (productId == null || productId.isEmpty) return null;
    if (productId.startsWith('item:')) {
      final id = productId.substring(5);
      return _isUuid(id) ? id : null;
    }
    return _isUuid(productId) ? productId : null;
  }

  /// 寫入 `order_items` 的快照欄位（不含 demand 專用欄位）。
  Map<String, dynamic> toOrderItemMap() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (brand != null && brand!.isNotEmpty) 'brand': brand,
        if (spec != null && spec!.isNotEmpty) 'spec': spec,
        if (unitLabel != null && unitLabel!.isNotEmpty) 'unit_label': unitLabel,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (supplyCategoryKey != null && supplyCategoryKey!.isNotEmpty)
          'supply_category_key': supplyCategoryKey,
        if (templateOptionId != null && templateOptionId!.isNotEmpty)
          'template_option_id': templateOptionId,
        if (pxProductId != null && pxProductId!.isNotEmpty)
          'px_product_id': pxProductId,
        if (sourceUrl != null && sourceUrl!.isNotEmpty) 'source_url': sourceUrl,
        if (pxSearchKeyword != null && pxSearchKeyword!.isNotEmpty)
          'px_search_keyword': pxSearchKeyword,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
        if (referenceNote != null && referenceNote!.isNotEmpty)
          'reference_note': referenceNote,
      };

  /// 寫入 `demand_record_items`（含履行狀態與標準化欄位）。
  Map<String, dynamic> toDemandRecordItemMap() => {
        ...toOrderItemMap(),
        if (_isUuid(categoryId)) 'category_id': categoryId,
        if (_isUuid(brandId)) 'brand_id': brandId,
        if (_isUuid(parseProductItemId(productId, explicit: productItemId)))
          'product_item_id':
              parseProductItemId(productId, explicit: productItemId),
        if (normalizeConfidence != null)
          'normalize_confidence': normalizeConfidence,
        'normalized_at': DateTime.now().toUtc().toIso8601String(),
        'fulfillment_status': 'pending',
      };

  factory SupplyLineSnapshot.fromItemMap(Map<String, dynamic> m) {
    return SupplyLineSnapshot(
      productId: m['product_id']?.toString() ?? '',
      productName: m['product_name']?.toString() ?? '',
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (m['unit_price'] as num?)?.toDouble(),
      brand: m['brand']?.toString(),
      spec: m['spec']?.toString(),
      unitLabel: m['unit_label']?.toString(),
      category: m['category']?.toString(),
      supplyCategoryKey: m['supply_category_key']?.toString(),
      templateOptionId: m['template_option_id']?.toString(),
      pxProductId: m['px_product_id']?.toString(),
      sourceUrl: m['source_url']?.toString(),
      pxSearchKeyword: m['px_search_keyword']?.toString(),
      imageUrl: m['image_url']?.toString(),
      referenceNote: m['reference_note']?.toString(),
      categoryId: m['category_id']?.toString(),
      brandId: m['brand_id']?.toString(),
      productItemId: m['product_item_id']?.toString(),
      normalizeConfidence: (m['normalize_confidence'] as num?)?.toDouble(),
    );
  }
}
