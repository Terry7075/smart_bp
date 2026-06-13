/// 待聚合單筆明細。
final class BatchItemInput {
  const BatchItemInput({
    required this.itemId,
    required this.demandRecordId,
    required this.elderUserId,
    required this.categoryKey,
    required this.categoryLabel,
    this.brandLabel,
    this.categoryId,
    this.brandId,
    required this.quantity,
    this.unitLabel,
  });

  final String itemId;
  final String demandRecordId;
  final String elderUserId;
  final String categoryKey;
  final String categoryLabel;
  final String? brandLabel;
  final String? categoryId;
  final String? brandId;
  final int quantity;
  final String? unitLabel;
}

/// 聚合後批次明細。
final class AggregatedBatchLine {
  const AggregatedBatchLine({
    this.categoryId,
    this.brandId,
    required this.categoryLabel,
    this.brandLabel,
    required this.aggregatedQuantity,
    this.unitLabel,
    required this.sourceItemIds,
    required this.demandRecordIds,
    required this.elderUserIds,
  });

  final String? categoryId;
  final String? brandId;
  final String categoryLabel;
  final String? brandLabel;
  final int aggregatedQuantity;
  final String? unitLabel;
  final List<String> sourceItemIds;
  final Set<String> demandRecordIds;
  final Map<String, String> elderUserIds;
}

/// 貪婪聚合 O(n)：同據點、同 category+brand 合併數量。
abstract final class PurchaseBatchAggregator {
  static List<AggregatedBatchLine> aggregate(List<BatchItemInput> items) {
    final groups = <String, List<BatchItemInput>>{};
    for (final item in items) {
      final brandKey = item.brandLabel?.trim().isNotEmpty == true
          ? item.brandLabel!.trim()
          : '_any';
      final key = '${item.categoryKey}|$brandKey';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final out = <AggregatedBatchLine>[];
    for (final group in groups.values) {
      if (group.isEmpty) continue;
      final first = group.first;
      var sum = 0;
      final sourceIds = <String>[];
      final recordIds = <String>{};
      final elders = <String, String>{};
      for (final g in group) {
        sum += g.quantity;
        sourceIds.add(g.itemId);
        recordIds.add(g.demandRecordId);
        elders[g.demandRecordId] = g.elderUserId;
      }
      out.add(
        AggregatedBatchLine(
          categoryId: first.categoryId,
          brandId: first.brandId,
          categoryLabel: first.categoryLabel,
          brandLabel: first.brandLabel,
          aggregatedQuantity: sum,
          unitLabel: first.unitLabel,
          sourceItemIds: sourceIds,
          demandRecordIds: recordIds,
          elderUserIds: elders,
        ),
      );
    }
    return out;
  }
}
