import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';

final class AdminOrderStats {
  const AdminOrderStats({
    required this.totalOrders,
    required this.pendingCount,
    required this.processingCount,
    required this.completedCount,
    required this.stuckCount,
    required this.hotProducts,
    required this.draftDemandCount,
  });

  final int totalOrders;
  final int pendingCount;
  final int processingCount;
  final int completedCount;
  final int stuckCount;
  final List<({String name, int qty})> hotProducts;

  /// 語音／小幫手尚未送出的 demand_records 草稿數。
  final int draftDemandCount;
}

final adminOrdersProvider = FutureProvider<List<ShopOrderListRow>>((ref) async {
  return ref.read(shopOrdersRepositoryProvider).listOrdersForAdmin(limit: 200);
});

final adminStatsProvider = FutureProvider<AdminOrderStats>((ref) async {
  final orders = await ref.read(adminOrdersProvider.future);
  final now = DateTime.now();
  var pending = 0, processing = 0, completed = 0, stuck = 0;
  final productQty = <String, int>{};

  for (final o in orders) {
    if (o.status == 'pending') pending++;
    if (o.status == 'processing') processing++;
    if (o.status == 'completed') completed++;
    if (o.status != 'completed' &&
        o.status != 'cancelled' &&
        now.difference(o.createdAt).inHours >= 24) {
      stuck++;
    }
    for (final it in o.items) {
      productQty[it.productName] = (productQty[it.productName] ?? 0) + it.quantity;
    }
  }

  final hot = productQty.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  var draftDemands = 0;
  try {
    final drafts =
        await ref.read(demandRecordsRepositoryProvider).listDraftsForVolunteer();
    draftDemands = drafts.where((d) => d.status == 'draft').length;
  } catch (_) {}

  return AdminOrderStats(
    totalOrders: orders.length,
    pendingCount: pending,
    processingCount: processing,
    completedCount: completed,
    stuckCount: stuck,
    hotProducts: hot.take(5).map((e) => (name: e.key, qty: e.value)).toList(),
    draftDemandCount: draftDemands,
  );
});
