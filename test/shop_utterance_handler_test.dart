import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/shop/data/shop_utterance_handler.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

void main() {
  test('classificationFromNlu maps record_demand', () {
    const result = ShopNluResult(
      confidence: 0.9,
      source: 'rule',
      intent: 'record_demand',
      categoryKey: 'egg',
      categoryLabel: '雞蛋',
      brandName: '洗選鮮蛋',
      quantity: 2,
    );
    final c = ShopUtteranceHandler.classificationFromNlu(result, '我要買兩盒雞蛋');
    expect(c.intent, AssistantShopIntent.recordDemand);
    expect(c.slots?.lines.first.productName, '洗選鮮蛋');
    expect(c.slots?.lines.first.quantity, 2);
  });

  test('classificationFromNlu maps query_price', () {
    const result = ShopNluResult(
      confidence: 0.85,
      source: 'rule',
      intent: 'query_price',
      categoryLabel: '雞蛋',
    );
    final c = ShopUtteranceHandler.classificationFromNlu(result, '雞蛋多少錢');
    expect(c.intent, AssistantShopIntent.queryPrice);
  });
}
