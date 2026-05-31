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

  Map<String, dynamic> toInsertMap() => {
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
    );
  }
}
