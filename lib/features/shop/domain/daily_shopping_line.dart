/// 今日採買清單聚合明細。
final class DailyShoppingElderLine {
  const DailyShoppingElderLine({
    required this.itemId,
    required this.elderUserId,
    required this.elderDisplay,
    required this.quantity,
    required this.demandRecordId,
  });

  final String itemId;
  final String elderUserId;
  final String elderDisplay;
  final int quantity;
  final String demandRecordId;

  factory DailyShoppingElderLine.fromJson(Map<String, dynamic> j) {
    return DailyShoppingElderLine(
      itemId: j['item_id']?.toString() ?? '',
      elderUserId: j['elder_user_id']?.toString() ?? '',
      elderDisplay: j['elder_display']?.toString() ?? '長輩',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      demandRecordId: j['demand_record_id']?.toString() ?? '',
    );
  }
}

final class DailyShoppingLine {
  const DailyShoppingLine({
    required this.groupKey,
    this.productItemId,
    required this.categoryLabel,
    this.brandLabel,
    this.specLabel,
    required this.unitLabel,
    required this.totalQty,
    required this.elderLines,
  });

  final String groupKey;
  final String? productItemId;
  final String categoryLabel;
  final String? brandLabel;
  final String? specLabel;
  final String unitLabel;
  final int totalQty;
  final List<DailyShoppingElderLine> elderLines;

  String get displayTitle {
    final parts = [
      categoryLabel,
      if (brandLabel != null && brandLabel!.isNotEmpty) brandLabel,
      if (specLabel != null && specLabel!.isNotEmpty) specLabel,
    ];
    return parts.join('｜');
  }

  factory DailyShoppingLine.fromJson(Map<String, dynamic> j) {
    final elders = j['elder_lines'];
    return DailyShoppingLine(
      groupKey: j['group_key']?.toString() ?? '',
      productItemId: j['product_item_id']?.toString(),
      categoryLabel: j['category_label']?.toString() ?? '未分類',
      brandLabel: j['brand_label']?.toString(),
      specLabel: j['spec_label']?.toString(),
      unitLabel: j['unit_label']?.toString() ?? '包',
      totalQty: (j['total_qty'] as num?)?.toInt() ?? 0,
      elderLines: elders is List
          ? elders
              .whereType<Map>()
              .map((e) => DailyShoppingElderLine.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }
}
