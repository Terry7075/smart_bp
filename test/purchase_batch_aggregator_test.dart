import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/purchase_batch_aggregator.dart';

void main() {
  test('同據點同品類同品牌合併數量', () {
    final lines = PurchaseBatchAggregator.aggregate([
      const BatchItemInput(
        itemId: 'a1',
        demandRecordId: 'd1',
        elderUserId: 'u1',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 2,
      ),
      const BatchItemInput(
        itemId: 'a2',
        demandRecordId: 'd2',
        elderUserId: 'u2',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 2,
      ),
      const BatchItemInput(
        itemId: 'a3',
        demandRecordId: 'd3',
        elderUserId: 'u3',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 2,
      ),
    ]);
    expect(lines.length, 1);
    expect(lines.first.aggregatedQuantity, 6);
    expect(lines.first.sourceItemIds.length, 3);
  });

  test('同品類不同品牌分兩行', () {
    final lines = PurchaseBatchAggregator.aggregate([
      const BatchItemInput(
        itemId: 'a1',
        demandRecordId: 'd1',
        elderUserId: 'u1',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '五月花',
        quantity: 1,
      ),
      const BatchItemInput(
        itemId: 'a2',
        demandRecordId: 'd2',
        elderUserId: 'u2',
        categoryKey: 'tissue',
        categoryLabel: '衛生紙',
        brandLabel: '舒潔',
        quantity: 1,
      ),
    ]);
    expect(lines.length, 2);
  });
}
