import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';

/// 小幫手回答時使用的使用者即時狀態（來自 Supabase）。
class AssistantSnapshot {
  const AssistantSnapshot({
    this.displayName,
    this.latestPrescription,
    this.recentOrders = const [],
  });

  final String? displayName;
  final VolunteerTask? latestPrescription;
  final List<ShopOrderListRow> recentOrders;
}
