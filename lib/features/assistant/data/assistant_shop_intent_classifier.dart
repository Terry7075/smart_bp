import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/data/shop_quantity_parser.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';

/// 三層意圖分類：關鍵字 → 正則 → 同義詞（報告 5.2.2）。
abstract final class AssistantShopIntentClassifier {
  static ShopIntentClassification classify(String raw) {
    final sw = Stopwatch()..start();
    final n = _norm(raw);
    if (n.isEmpty) {
      sw.stop();
      return ShopIntentClassification(
        intent: AssistantShopIntent.casual,
        layer: 'L0',
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final l1 = _layer1(n, raw);
    if (l1 != null) {
      sw.stop();
      return ShopIntentClassification(
        intent: l1.$1,
        layer: 'L1',
        slots: l1.$2,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final l2 = _layer2(n, raw);
    if (l2 != null) {
      sw.stop();
      return ShopIntentClassification(
        intent: l2.$1,
        layer: 'L2',
        slots: l2.$2,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final l3 = _layer3(n, raw);
    if (l3 != null) {
      sw.stop();
      return ShopIntentClassification(
        intent: l3.$1,
        layer: 'L3',
        slots: l3.$2,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    sw.stop();
    return ShopIntentClassification(
      intent: AssistantShopIntent.casual,
      layer: 'L3',
      elapsedMs: sw.elapsedMilliseconds,
    );
  }

  static String _norm(String q) =>
      q.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _has(String n, List<String> keys) {
    for (final k in keys) {
      if (n.contains(k)) return true;
    }
    return false;
  }

  static (AssistantShopIntent, ShopIntentSlots?)? _layer1(
    String n,
    String raw,
  ) {
    if (_has(n, ['不要了', '取消', '刪掉', '不用買', '改不要'])) {
      return (
        AssistantShopIntent.cancelDemand,
        ShopIntentSlots(singleProduct: _extractProductForCancel(raw)),
      );
    }
    if (_has(n, ['多少錢', '價格', '價錢', '參考價', '賣多少'])) {
      return (
        AssistantShopIntent.queryPrice,
        ShopIntentSlots(singleProduct: _extractProductForPrice(raw)),
      );
    }
    if (_has(n, [
      '到哪了', '到了嗎', '送到了嗎', '接單了嗎', '接了嗎', '接了沒',
      '訂單狀態', '查訂單', '處理了嗎', '處理了沒', '送來了嗎',
    ])) {
      return (AssistantShopIntent.queryOrderStatus, null);
    }
    if (_has(n, ['買了什麼', '記錄什麼', '說要買什麼', '剛剛買', '我的需求', '記了什麼'])) {
      return (AssistantShopIntent.viewRecorded, null);
    }
    final shortage = _tryShortageSuggest(n, raw);
    if (shortage != null) return shortage;
    if (_has(n, ['買', '購買', '採買', '要買', '想買', '幫我買', '記下', '加入'])) {
      final lines = _parseBuyLines(raw);
      if (lines.isNotEmpty) {
        return (
          AssistantShopIntent.recordDemand,
          ShopIntentSlots(lines: lines),
        );
      }
    }
    return null;
  }

  static (AssistantShopIntent, ShopIntentSlots?)? _layer2(
    String n,
    String raw,
  ) {
    final parsed = ShopQuantityParser.parseCategoryRequest(raw);
    if (parsed != null) {
      final cat = ElderSupplyTemplates.findCategoryByKeyword(parsed.categoryKeyword);
      if (cat != null) {
        return (
          AssistantShopIntent.recordDemand,
          ShopIntentSlots(
            lines: [
              DemandLineSlot(
                productName: parsed.categoryKeyword,
                quantity: parsed.quantity,
              ),
            ],
          ),
        );
      }
    }
    final buyQty = RegExp(r'我要買(\d+)?([瓶包盒袋斤個件罐盒])?(.+)');
    final m1 = buyQty.firstMatch(n);
    if (m1 != null) {
      final qty = int.tryParse(m1.group(1) ?? '') ?? 1;
      final name = (m1.group(3) ?? '').trim();
      if (name.isNotEmpty) {
        return (
          AssistantShopIntent.recordDemand,
          ShopIntentSlots(lines: [DemandLineSlot(productName: name, quantity: qty)]),
        );
      }
    }

    final priceQ = RegExp(r'(.+?)(多少錢|價格|價錢)');
    final m2 = priceQ.firstMatch(n);
    if (m2 != null) {
      final name = (m2.group(1) ?? '').replaceAll(RegExp(r'^[那這個]+'), '').trim();
      if (name.isNotEmpty) {
        return (
          AssistantShopIntent.queryPrice,
          ShopIntentSlots(singleProduct: name),
        );
      }
    }

    final cancelQ = RegExp(r'那個(.+?)(不要了|取消|不用)');
    final m3 = cancelQ.firstMatch(n);
    if (m3 != null) {
      return (
        AssistantShopIntent.cancelDemand,
        ShopIntentSlots(singleProduct: m3.group(1)?.trim()),
      );
    }

    final viewQ = RegExp(r'(我|剛剛|剛才).*(買了什麼|要買什麼|記了什麼)');
    if (viewQ.hasMatch(n)) {
      return (AssistantShopIntent.viewRecorded, null);
    }

    final orderStatusQ = RegExp(
      r'(我的)?(東西|物資|訂單|需求)(送到哪|到哪了|到了嗎|怎麼了|狀態|進度)',
    );
    final volunteerQ = RegExp(r'志工.*(接|處理|來了|到了)');
    if (orderStatusQ.hasMatch(n) || volunteerQ.hasMatch(n)) {
      return (AssistantShopIntent.queryOrderStatus, null);
    }

    final shortage = _tryShortageSuggest(n, raw);
    if (shortage != null) return shortage;

    return null;
  }

  static (AssistantShopIntent, ShopIntentSlots?)? _layer3(
    String n,
    String raw,
  ) {
    const buySyn = ['購物', '添購', '買'];
    const priceSyn = ['價', '錢'];
    const cancelSyn = ['不要', '退掉'];
    const viewSyn = ['清單', '列表', '需求單'];

    if (_has(n, buySyn) && !n.contains('多少')) {
      final lines = _parseBuyLines(raw);
      if (lines.isNotEmpty) {
        return (
          AssistantShopIntent.recordDemand,
          ShopIntentSlots(lines: lines),
        );
      }
    }
    if (_has(n, priceSyn) && !n.contains('買')) {
      return (
        AssistantShopIntent.queryPrice,
        ShopIntentSlots(singleProduct: _extractProductForPrice(raw)),
      );
    }
    if (_has(n, cancelSyn)) {
      return (
        AssistantShopIntent.cancelDemand,
        ShopIntentSlots(singleProduct: _extractProductForCancel(raw)),
      );
    }
    if (_has(n, viewSyn)) {
      return (AssistantShopIntent.viewRecorded, null);
    }
    const orderStatusSyn = ['訂單', '配送', '進度'];
    if (_has(n, orderStatusSyn) && !_has(n, ['買', '購買', '添購'])) {
      return (AssistantShopIntent.queryOrderStatus, null);
    }
    return null;
  }

  static List<DemandLineSlot> _parseBuyLines(String raw) {
    var t = raw.trim();
    for (final prefix in ['我要買', '幫我買', '想買', '要買', '買', '記下', '加入']) {
      if (t.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }
    t = t.replaceAll(RegExp(r'[。！？,.，]'), '');
    if (t.isEmpty) return const [];

    final parts = t.split(RegExp(r'[和跟及、,，]'));
    final lines = <DemandLineSlot>[];
    for (final p in parts) {
      final seg = p.trim();
      if (seg.isEmpty) continue;
      final m = RegExp(r'^(\d+)?([瓶包盒袋斤個件罐])?(.+)$').firstMatch(seg);
      if (m != null) {
        final qty = int.tryParse(m.group(1) ?? '') ?? 1;
        final name = (m.group(3) ?? seg).trim();
        if (name.isNotEmpty) lines.add(DemandLineSlot(productName: name, quantity: qty));
      } else {
        lines.add(DemandLineSlot(productName: seg));
      }
    }
    return lines;
  }

  static String? _extractProductForPrice(String raw) {
    final n = _norm(raw);
    final m = RegExp(r'(.+?)(多少錢|價格|價錢)').firstMatch(n);
    if (m != null) {
      final name = (m.group(1) ?? '').replaceAll(RegExp(r'^[那這個]+'), '').trim();
      return name.isEmpty ? null : name;
    }
    return raw.replaceAll(RegExp(r'多少錢|價格|價錢|查'), '').trim();
  }

  static const _shortageSignals = [
    '沒了',
    '沒有了',
    '用完了',
    '用完',
    '快沒了',
    '快用完',
    '不夠了',
    '缺了',
    '沒有了',
  ];

  static const _shortageExclude = [
    '沒事',
    '沒關係',
    '沒問題',
    '沒辦法',
    '沒想到',
    '沒有錢',
    '沒有時間',
  ];

  static (AssistantShopIntent, ShopIntentSlots?)? _tryShortageSuggest(
    String n,
    String raw,
  ) {
    if (_has(n, _shortageExclude)) return null;
    final hasSignal = _has(n, _shortageSignals) ||
        RegExp(r'沒有.+?了').hasMatch(n);
    if (!hasSignal) return null;
    if (_has(n, ['買', '購買', '要買', '想買', '幫我買', '採買'])) return null;

    final product = _extractProductForShortage(raw);
    if (product == null || product.isEmpty) return null;

    return (
      AssistantShopIntent.shortageSuggest,
      ShopIntentSlots(singleProduct: product),
    );
  }

  static String? _extractProductForShortage(String raw) {
    final n = _norm(raw);
    final patterns = <RegExp>[
      RegExp(r'我家(.+?)沒了'),
      RegExp(r'家裡(.+?)沒了'),
      RegExp(r'沒有(.+?)了'),
      RegExp(r'(.+?)沒有了'),
      RegExp(r'(.+?)快沒了'),
      RegExp(r'(.+?)用完了'),
      RegExp(r'(.+?)快用完'),
      RegExp(r'(.+?)不夠了'),
      RegExp(r'(.+?)缺了'),
      RegExp(r'(.+?)沒了'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(n);
      if (m == null) continue;
      final name = _cleanShortageProduct(m.group(1) ?? '');
      if (name.isNotEmpty && name.length <= 24) return name;
    }
    return null;
  }

  static String _cleanShortageProduct(String name) {
    var t = name.trim();
    for (final prefix in ['我家', '家裡', '的', '一些', '一點', '還有']) {
      if (t.startsWith(prefix)) {
        t = t.substring(prefix.length);
      }
    }
    t = t.replaceAll(RegExp(r'(了|啊|呢|喔|哦|啦)$'), '');
    return t.trim();
  }

  static String? _extractProductForCancel(String raw) {
    final n = _norm(raw);
    final m = RegExp(r'那個(.+?)(不要|取消)').firstMatch(n);
    if (m != null) return m.group(1)?.trim();
    return raw
        .replaceAll(RegExp(r'不要了|取消|刪掉|不用買|那個'), '')
        .trim();
  }
}
