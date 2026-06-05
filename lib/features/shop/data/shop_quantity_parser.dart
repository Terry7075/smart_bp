/// 從語音／文字解析「兩包」「1盒」等數量與單位。
abstract final class ShopQuantityParser {
  static const unitChars = '瓶包盒袋斤個件罐組提捲';

  static const Map<String, int> _cnQty = {
    '一': 1,
    '二': 2,
    '兩': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
  };

  static ({int quantity, String? unitLabel, String categoryKeyword})?
      parseCategoryRequest(String raw) {
    var t = raw.trim();
    for (final prefix in [
      '我要',
      '想要',
      '想買',
      '要買',
      '幫我買',
      '買',
      '記下',
      '加入',
      '採買',
    ]) {
      if (t.startsWith(prefix)) {
        t = t.substring(prefix.length).trim();
        break;
      }
    }
    t = t.replaceAll(RegExp(r'[。！？,.，]'), '').replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return null;

    final trailing = RegExp(r'^(.+?)(\d+)([' + unitChars + r'])$');
    final mt = trailing.firstMatch(t);
    if (mt != null) {
      final name = (mt.group(1) ?? '').trim();
      final qty = int.tryParse(mt.group(2) ?? '') ?? 1;
      final unit = mt.group(3);
      if (name.isNotEmpty) {
        return (quantity: qty, unitLabel: unit, categoryKeyword: name);
      }
    }
    final trailingCn = RegExp(
      r'^(.+?)([一二兩三四五六七八九十])([' + unitChars + r'])$',
    );
    final mcn = trailingCn.firstMatch(t);
    if (mcn != null) {
      final name = (mcn.group(1) ?? '').trim();
      final qty = _cnQty[mcn.group(2)] ?? 1;
      final unit = mcn.group(3);
      if (name.isNotEmpty) {
        return (quantity: qty, unitLabel: unit, categoryKeyword: name);
      }
    }

    final m = RegExp(r'^(\d+)?([' + unitChars + r'])?(.+)$').firstMatch(t);
    if (m == null) {
      return (quantity: 1, unitLabel: null, categoryKeyword: t);
    }
    final qty = int.tryParse(m.group(1) ?? '') ?? 1;
    final unit = m.group(2);
    var name = (m.group(3) ?? t).trim();
    name = name.replaceAll(RegExp(r'(了|啊|呢|喔|哦|啦)$'), '');
    if (name.isEmpty) return null;
    return (quantity: qty, unitLabel: unit, categoryKeyword: name);
  }
}
