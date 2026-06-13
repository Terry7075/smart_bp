/// 判斷手動輸入品項是否足夠讓志工採買（品牌／容量）。
abstract final class ShopDemandCompleteness {
  static final _specRe = RegExp(
    r'\d+\s*(ml|mL|ML|kg|g|公升|入|抽|號|包|罐|盒|袋)',
    caseSensitive: false,
  );

  static bool isLikelyComplete(String keyword) {
    final t = keyword.trim();
    if (t.isEmpty) return false;
    if (RegExp(r'【[^】]+】').hasMatch(t)) return true;
    if (_specRe.hasMatch(t)) return true;
    if (t.length >= 12) return true;
    return false;
  }

  static bool needsBrandCapacityPrompt(String keyword) =>
      !isLikelyComplete(keyword);
}
