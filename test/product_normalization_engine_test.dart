import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/product_normalization_engine.dart';

void main() {
  final engine = ProductNormalizationEngine();

  test('衛生紙兩包 → 品類衛生紙、需追問品牌', () {
    final c = engine.normalize('我要買衛生紙兩包');
    expect(c.categoryKey, 'tissue');
    expect(c.category, '衛生紙');
    expect(c.quantity, 2);
    expect(c.hasBrand, isFalse);
    expect(c.needsBrandClarification, isTrue);
  });

  test('五月花衛生紙 → 品牌五月花', () {
    final c = engine.normalize('我要買五月花衛生紙');
    expect(c.categoryKey, 'tissue');
    expect(c.brand, '五月花');
    expect(c.hasBrand, isTrue);
    expect(c.matchLayer, contains('brand'));
  });

  test('抽取式衛生紙 → 品類正確', () {
    final c = engine.normalize('我要買抽取式衛生紙');
    expect(c.categoryKey, 'tissue');
    expect(c.quantity, greaterThanOrEqualTo(1));
  });

  test('toSnapshot 含 supply_category_key', () {
    final c = engine.normalize('我要買五月花衛生紙兩提');
    final snap = engine.toSnapshot(c);
    expect(snap, isNotNull);
    expect(snap!.supplyCategoryKey, 'tissue');
    expect(snap.brand, '五月花');
    expect(snap.quantity, 2);
  });
}
