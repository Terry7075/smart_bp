import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/data/shop_quantity_parser.dart';
import 'package:smart_bp/features/shop/data/supply_dialogue_service.dart';

void main() {
  test('解析我要衛生紙兩包', () {
    final parsed = ShopQuantityParser.parseCategoryRequest('我要衛生紙兩包');
    expect(parsed, isNotNull);
    expect(parsed!.categoryKeyword, '衛生紙');
    expect(parsed.quantity, 2);
  });

  test('啟動品牌追問', () {
    const svc = SupplyDialogueService();
    final pending = svc.tryStartFromUtterance('我要衛生紙兩包');
    expect(pending, isNotNull);
    expect(pending!.categoryKey, 'tissue');
    final reply = svc.brandAskReplyFor(pending);
    expect(reply.brandChoices.length, greaterThanOrEqualTo(3));
  });

  test('選品牌後產生快照', () {
    const svc = SupplyDialogueService();
    final pending = svc.tryStartFromUtterance('我要衛生紙兩包')!;
    final r = svc.handlePending(pending: pending, userText: '2');
    expect(r.snapshot, isNotNull);
    expect(r.snapshot!.brand, '五月花');
    expect(r.snapshot!.quantity, 2);
  });

  test('模板涵蓋衛生紙', () {
    final cat = ElderSupplyTemplates.findCategoryByKeyword('衛生紙');
    expect(cat?.key, 'tissue');
    expect(cat!.options.length, greaterThanOrEqualTo(3));
  });
}
