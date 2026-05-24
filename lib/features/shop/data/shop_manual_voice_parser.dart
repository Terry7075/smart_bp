/// 將長輩口語（含「全聯的鮮奶兩罐」）解析成單一品項描述，供志工採買。
abstract final class ShopManualVoiceParser {
  static ParsedManualVoiceItem parse(String raw) {
    var t = raw.trim();
    if (t.isEmpty) {
      return const ParsedManualVoiceItem(
        displayName: '',
        pxSearchKeyword: '',
        quantity: 1,
      );
    }

    var qty = 1;
    String unitSuffix = '';
    final qtyMatch = RegExp(
      r'(\d+)\s*(罐|包|盒|袋|瓶|入|個|件|條|支|組)?\s*$',
    ).firstMatch(t);
    if (qtyMatch != null) {
      qty = int.tryParse(qtyMatch.group(1) ?? '') ?? 1;
      unitSuffix = qtyMatch.group(2) ?? '';
      t = t.substring(0, qtyMatch.start).trim();
    } else {
      final cnQty = RegExp(
        r'(一|二|兩|三|四|五|六|七|八|九|十)\s*(罐|包|盒|袋|瓶|入|個|件|條|支|組)?\s*$',
      ).firstMatch(t);
      if (cnQty != null) {
        qty = _cnDigit(cnQty.group(1) ?? '一');
        unitSuffix = cnQty.group(2) ?? '';
        t = t.substring(0, cnQty.start).trim();
      }
    }

    for (final prefix in [
      '幫我在全聯找',
      '幫我在全聯買',
      '全聯有沒有',
      '全聯的',
      '全聯',
      '我要買',
      '幫我買',
      '想買',
      '要買',
      '買',
      '搜尋',
      '找',
    ]) {
      if (t.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }

    t = t.replaceAll(RegExp(r'[。！？,.，、]'), '').trim();
    final keyword = t;
    final display = unitSuffix.isNotEmpty
        ? '$t $qty$unitSuffix'
        : (qty > 1 ? '$t ×$qty' : t);

    return ParsedManualVoiceItem(
      displayName: display,
      pxSearchKeyword: keyword.isEmpty ? t : keyword,
      quantity: qty.clamp(1, 999),
    );
  }

  static int _cnDigit(String s) => switch (s) {
        '一' => 1,
        '二' || '兩' => 2,
        '三' => 3,
        '四' => 4,
        '五' => 5,
        '六' => 6,
        '七' => 7,
        '八' => 8,
        '九' => 9,
        '十' => 10,
        _ => 1,
      };
}

final class ParsedManualVoiceItem {
  const ParsedManualVoiceItem({
    required this.displayName,
    required this.pxSearchKeyword,
    required this.quantity,
  });

  final String displayName;
  final String pxSearchKeyword;
  final int quantity;

  bool get isValid => displayName.trim().isNotEmpty && pxSearchKeyword.trim().isNotEmpty;
}
