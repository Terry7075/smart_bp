import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';

/// 每天訂單數統計（近 7 天）。
final class DayOrderCount {
  const DayOrderCount({required this.date, required this.count});
  final DateTime date;
  final int count;
}

/// 近 7 天每日訂單數 + Top5 熱門品項（用於圖表）。
final adminChartDataProvider = FutureProvider<
    ({List<DayOrderCount> ordersByDay, List<({String name, int qty})> top5, List<({String name, int qty})> topCategories, List<({String name, int qty})> topBrands})>(
  (ref) async {
    final orders = await ref.read(adminOrdersProvider.future);
    final now = DateTime.now();

    // 近 7 天日期 key（格式：yyyy-MM-dd）
    final Map<String, int> byDay = {};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      byDay['${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] = 0;
    }

    final productQty = <String, int>{};
    final categoryQty = <String, int>{};
    final brandQty = <String, int>{};
    for (final o in orders) {
      final key =
          '${o.createdAt.year}-${o.createdAt.month.toString().padLeft(2, '0')}-${o.createdAt.day.toString().padLeft(2, '0')}';
      if (byDay.containsKey(key)) {
        byDay[key] = (byDay[key] ?? 0) + 1;
      }
      for (final it in o.items) {
        productQty[it.productName] =
            (productQty[it.productName] ?? 0) + it.quantity;
        final cat = it.supplyCategoryKey ?? it.category;
        if (cat != null && cat.trim().isNotEmpty) {
          categoryQty[cat] = (categoryQty[cat] ?? 0) + it.quantity;
        }
        if (it.brand != null && it.brand!.trim().isNotEmpty) {
          brandQty[it.brand!] = (brandQty[it.brand!] ?? 0) + it.quantity;
        }
      }
    }

    final ordersByDay = byDay.entries
        .map((e) => DayOrderCount(date: DateTime.parse(e.key), count: e.value))
        .toList();

    final sortedProducts = productQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedProducts
        .take(5)
        .map((e) => (name: e.key, qty: e.value))
        .toList();

    final topCategories = categoryQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBrands = brandQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (
      ordersByDay: ordersByDay,
      top5: top5,
      topCategories: topCategories.take(5).map((e) => (name: e.key, qty: e.value)).toList(),
      topBrands: topBrands.take(5).map((e) => (name: e.key, qty: e.value)).toList(),
    );
  },
);

final class AdminOrderStats {
  const AdminOrderStats({
    required this.totalOrders,
    required this.pendingCount,
    required this.processingCount,
    required this.completedCount,
    required this.activeCount,
    required this.hotProducts,
    required this.draftDemandCount,
  });

  final int totalOrders;
  final int pendingCount;
  final int processingCount;
  final int completedCount;
  /// 進行中需求（待接單 + 已接單／採買中），志工待處理總量。
  final int activeCount;
  final List<({String name, int qty})> hotProducts;

  /// 語音／小幫手尚未送出的 demand_records 草稿數。
  final int draftDemandCount;
}

/// 志工端數據總覽：訂單列表（依志工 RLS 可見範圍）。
final adminOrdersProvider = FutureProvider<List<ShopOrderListRow>>((ref) async {
  final repo = ref.read(shopOrdersRepositoryProvider);
  return repo.listOrdersWithItemsForVolunteer(limit: 200);
});

final adminStatsProvider = FutureProvider<AdminOrderStats>((ref) async {
  final orders = await ref.read(adminOrdersProvider.future);
  var pending = 0, processing = 0, completed = 0;
  final productQty = <String, int>{};

  for (final o in orders) {
    if (o.status == 'pending') pending++;
    if (o.status == 'processing') processing++;
    if (o.status == 'completed') completed++;
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
    activeCount: pending + processing,
    hotProducts: hot.take(5).map((e) => (name: e.key, qty: e.value)).toList(),
    draftDemandCount: draftDemands,
  );
});
