import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';

/// 小幫手 → 柑仔店代購導航（與主流程送出鈕對齊）。
abstract final class AssistantShopNavigation {
  /// 開啟柑仔店並提示「送出給志工」按鈕（`?focus=submit`）。
  static const submit = AssistantNavAction(
    label: '前往柑仔店送出',
    route: '/shop',
    queryParameters: {'focus': 'submit'},
  );

  static const browse = AssistantNavAction(
    label: '前往柑仔店',
    route: '/shop',
  );

  static const orders = AssistantNavAction(
    label: '查看需求紀錄',
    route: '/shop/orders',
  );

  /// 品牌追問或已寫入草稿時的建議按鈕順序。
  static List<AssistantNavAction> followUpActions({
    List<AssistantNavAction> extra = const [],
    bool includeOrders = false,
  }) {
    return [
      submit,
      if (includeOrders) orders,
      ...extra,
    ];
  }
}
