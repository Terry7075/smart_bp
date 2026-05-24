import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';

/// 小幫手回答時使用的使用者即時狀態（來自 Supabase）。
class AssistantSnapshot {
  const AssistantSnapshot({
    this.displayName,
    this.latestPrescription,
    this.recentOrders = const [],
    this.loadedAt,
  });

  final String? displayName;
  final VolunteerTask? latestPrescription;
  final List<ShopOrderListRow> recentOrders;

  /// 本次從 Supabase 讀取完成的時間（供回覆標註資料新鮮度）。
  final DateTime? loadedAt;
}
