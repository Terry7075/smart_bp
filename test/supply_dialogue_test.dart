import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
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
    final svc = SupplyDialogueService();
    final pending = svc.tryStartFromUtterance('我要衛生紙兩包');
    expect(pending, isNotNull);
    expect(pending!.categoryKey, 'tissue');
    final reply = svc.brandAskReplyFor(pending);
    expect(reply.brandChoices.length, greaterThanOrEqualTo(3));
  });

  test('選品牌後選容量產生快照', () {
    final svc = SupplyDialogueService();
    final pending = svc.tryStartFromUtterance('我要衛生紙兩包')!;
    final afterBrand = svc.handlePending(pending: pending, userText: '五月花');
    expect(afterBrand.snapshot, isNull);
    expect(afterBrand.next?.step, SupplyDialogueStep.awaitCapacity);
    expect(afterBrand.next?.selectedBrand, '五月花');
    final afterCap = svc.handlePending(
      pending: afterBrand.next!,
      userText: '2',
    );
    expect(afterCap.snapshot, isNotNull);
    expect(afterCap.snapshot!.brand, '五月花');
    expect(afterCap.snapshot!.quantity, 2);
    expect(afterCap.snapshot!.spec, contains('100抽'));
  });

  test('無指定品牌可自填容量', () {
    final svc = SupplyDialogueService();
    final pending = svc.tryStartFromUtterance('我要鮮奶一瓶')!;
    final afterBrand = svc.handlePending(
      pending: pending,
      userText: ElderSupplyTemplates.unspecifiedBrandLabel,
    );
    expect(afterBrand.next?.step, SupplyDialogueStep.awaitCapacity);
    final afterCap = svc.handlePending(
      pending: afterBrand.next!,
      userText: '200ml',
    );
    expect(afterCap.snapshot, isNotNull);
    expect(afterCap.snapshot!.brand, ElderSupplyTemplates.unspecifiedBrandLabel);
    expect(afterCap.snapshot!.spec, '200ml');
    expect(afterCap.snapshot!.referenceNote, contains('志工代選品牌'));
  });

  test('模板涵蓋衛生紙與無指定品牌', () {
    final cat = ElderSupplyTemplates.findCategoryByKeyword('衛生紙');
    expect(cat?.key, 'tissue');
    expect(cat!.options.length, greaterThanOrEqualTo(5));
    expect(cat.options.any((o) => o.isUnspecified), isTrue);
    expect(cat.options.any((o) => o.brand == '五月花'), isTrue);
    expect(ElderSupplyTemplates.optionsForBrand(cat, '五月花').length, 2);
  });

  test('洗衣精與成人尿布模板', () {
    expect(ElderSupplyTemplates.findCategoryByKeyword('洗衣精')?.key, 'detergent');
    expect(ElderSupplyTemplates.findCategoryByKeyword('成人尿布')?.key, 'diaper');
  });

  test('無指定品牌產生快照', () {
    final cat = ElderSupplyTemplates.findCategoryByKeyword('衛生紙')!;
    final opt = ElderSupplyTemplates.capacityPresetsForCategory(cat).first;
    final snap = ElderSupplyTemplates.buildSnapshot(
      category: cat,
      option: opt,
      quantity: 2,
    );
    expect(snap.brand, ElderSupplyTemplates.unspecifiedBrandLabel);
    expect(snap.productName, contains('衛生紙'));
    expect(snap.spec, isNotEmpty);
  });
}
