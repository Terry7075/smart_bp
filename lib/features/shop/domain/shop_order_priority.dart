import 'package:smart_bp/features/shop/domain/shop_order_models.dart';

/// 志工待辦排序：待處理越久、處理中越久未更新者優先。
abstract final class ShopOrderPriority {
  static List<ShopOrderListRow> sortVolunteerQueue(List<ShopOrderListRow> orders) {
    final copy = [...orders];
    copy.sort((a, b) => score(b).compareTo(score(a)));
    return copy;
  }

  static int score(ShopOrderListRow o) {
    final now = DateTime.now();
    if (o.status == 'pending') {
      final ageH = now.difference(o.createdAt).inHours;
      return 2000 + ageH.clamp(0, 720);
    }
    if (o.status == 'processing') {
      final anchor = o.deliveryEvents.isNotEmpty
          ? o.deliveryEvents.last.createdAt
          : o.createdAt;
      final stagnantH = now.difference(anchor).inHours;
      return 1000 + stagnantH.clamp(0, 720);
    }
    return o.createdAt.millisecondsSinceEpoch ~/ 1000;
  }
}
