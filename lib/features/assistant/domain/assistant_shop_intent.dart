/// 第五章報告：智慧小幫手五類意圖。
enum AssistantShopIntent {
  /// 記錄需求（「我要買米和醬油」）
  recordDemand,

  /// 查詢價格（「雞蛋多少錢」）
  queryPrice,

  /// 查看已記錄（「我剛剛說要買什麼」）
  viewRecorded,

  /// 取消需求（「那個牛奶不要了」）
  cancelDemand,

  /// 一般對話
  casual,
}

/// 槽位：商品名稱與數量（簡化槽位填充）。
final class DemandLineSlot {
  const DemandLineSlot({required this.productName, this.quantity = 1});

  final String productName;
  final int quantity;
}

final class ShopIntentSlots {
  const ShopIntentSlots({this.lines = const [], this.singleProduct});

  final List<DemandLineSlot> lines;

  /// 查價／取消時單一商品名。
  final String? singleProduct;

  bool get isEmpty =>
      lines.isEmpty && (singleProduct == null || singleProduct!.trim().isEmpty);
}

final class ShopIntentClassification {
  const ShopIntentClassification({
    required this.intent,
    required this.layer,
    this.slots,
    this.elapsedMs = 0,
  });

  final AssistantShopIntent intent;
  final String layer;
  final ShopIntentSlots? slots;
  final int elapsedMs;

  String get intentLabel => switch (intent) {
        AssistantShopIntent.recordDemand => '記錄需求',
        AssistantShopIntent.queryPrice => '查詢價格',
        AssistantShopIntent.viewRecorded => '查看已記錄',
        AssistantShopIntent.cancelDemand => '取消需求',
        AssistantShopIntent.casual => '一般對話',
      };
}
