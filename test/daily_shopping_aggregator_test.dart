import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/purchase_batch_aggregator.dart';

void main() {
  test('aggregates same category brand', () {
    final lines = PurchaseBatchAggregator.aggregate([
      const BatchItemInput(
        itemId: 'a1',
        demandRecordId: 'r1',
        elderUserId: 'u1',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 2,
      ),
      const BatchItemInput(
        itemId: 'a2',
        demandRecordId: 'r2',
        elderUserId: 'u2',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 4,
      ),
    ]);
    expect(lines.length, 1);
    expect(lines.first.aggregatedQuantity, 6);
    expect(lines.first.sourceItemIds.length, 2);
  });
}
