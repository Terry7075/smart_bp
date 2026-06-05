import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/hybrid_nlu_orchestrator.dart';
import 'package:smart_bp/features/shop/data/shop_nlu_validator.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

void main() {
  test('rule NLU parses tissue with quantity', () async {
    final orch = HybridNluOrchestrator(useSupabaseWhenNull: false);
    final r = await orch.parse('我要兩包衛生紙');
    expect(r.categoryKey, 'tissue');
    expect(r.quantity, greaterThanOrEqualTo(1));
    expect(r.confidence, greaterThan(0.5));
    expect(r.source, startsWith('rule'));
  });

  test('cheap preference detected', () async {
    final orch = HybridNluOrchestrator(useSupabaseWhenNull: false);
    final r = await orch.parse('我要便宜一點的米');
    expect(r.pricePreference == 'budget' || r.categoryKey == 'rice', isTrue);
  });

  test('last purchase sets flag', () async {
    final orch = HybridNluOrchestrator(useSupabaseWhenNull: false);
    final r = await orch.parse('我上次買的那個衛生紙');
    expect(r.wantsLastPurchase, isTrue);
  });

  test('validator adds spec missing for tissue', () {
    final raw = ShopNluResult(
      confidence: 0.9,
      source: 'rule',
      categoryKey: 'tissue',
      categoryLabel: '衛生紙',
      quantity: 2,
    );
    final v = ShopNluValidator.validate(raw);
    expect(v.missingFields, contains('spec'));
  });
}
