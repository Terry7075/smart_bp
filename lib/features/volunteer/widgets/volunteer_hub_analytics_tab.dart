import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/admin/presentation/admin_providers.dart';
import 'package:smart_bp/features/shop/data/location_points_repository.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';

/// 志工儀表板「數據總覽」：原管理後台統計、圖表、據點物品、滯留單。
class VolunteerHubAnalyticsTab extends ConsumerWidget {
  const VolunteerHubAnalyticsTab({super.key});

  static const Color hubTeal = Color(0xFF00695C);
  static const Color hubBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final orders = ref.watch(adminOrdersProvider);
    final assetsAsync = ref.watch(_hubLocationAssetsProvider);
    final chartAsync = ref.watch(adminChartDataProvider);

    return RefreshIndicator(
      color: hubBlue,
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        ref.invalidate(adminOrdersProvider);
        ref.invalidate(adminChartDataProvider);
        ref.invalidate(communityAnalyticsProvider(null));
        ref.invalidate(_hubLocationAssetsProvider);
      },
      child: stats.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: VolunteerHubAnalyticsTab.hubBlue),
              ),
            ),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('載入統計失敗：$e', style: const TextStyle(fontSize: 17)),
          ],
        ),
        data: (s) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              '據點數據總覽',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '含柑仔店需求、今日採買與社區代購成效（與物資頁「今日採買清單」同一資料源）',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HubStatCard(
                  label: '總需求單',
                  value: '${s.totalOrders}',
                  color: hubTeal,
                ),
                _HubStatCard(
                  label: '待處理',
                  value: '${s.pendingCount}',
                  color: Colors.orange.shade800,
                ),
                _HubStatCard(
                  label: '處理中',
                  value: '${s.processingCount}',
                  color: Colors.blue.shade800,
                ),
                _HubStatCard(
                  label: '已完成',
                  value: '${s.completedCount}',
                  color: Colors.green.shade800,
                ),
                _HubStatCard(
                  label: '滯留>24h',
                  value: '${s.stuckCount}',
                  color: Colors.red.shade700,
                ),
                _HubStatCard(
                  label: '需求草稿',
                  value: '${s.draftDemandCount}',
                  color: Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/volunteer/shop-orders'),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('前往今日採買清單', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 20),
            const _HubCommunityAnalyticsSection(),
            const SizedBox(height: 20),
            chartAsync.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(color: hubBlue)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '近 7 天需求趨勢',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _HubOrderLineChart(ordersByDay: data.ordersByDay),
                  const SizedBox(height: 20),
                  const Text(
                    '熱門品項 Top5',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (data.top5.isEmpty)
                    const Card(child: ListTile(title: Text('尚無品項資料')))
                  else
                    _HubTop5BarChart(top5: data.top5),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const Text(
              '據點物品管理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            assetsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                '讀取據點物品失敗：$e',
                style: const TextStyle(fontSize: 16),
              ),
              data: (assets) {
                if (assets.isEmpty) {
                  return const Card(
                    child: ListTile(
                      title: Text('尚無據點物品資料', style: TextStyle(fontSize: 17)),
                      subtitle: Text('可在 Supabase location_assets 表新增'),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      for (final a in assets.take(12))
                        ListTile(
                          title: Text(a.itemName, style: const TextStyle(fontSize: 18)),
                          subtitle: Text(
                            a.locationName ?? a.locationPointId,
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: Text(
                            '× ${a.quantity}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '近期滯留需求',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            orders.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                final stuck = list.where((o) {
                  if (o.status == 'completed' || o.status == 'cancelled') {
                    return false;
                  }
                  return DateTime.now().difference(o.createdAt).inHours >= 24;
                }).take(10);
                if (stuck.isEmpty) {
                  return const Card(
                    child: ListTile(title: Text('目前無滯留超過 24 小時的單')),
                  );
                }
                return Column(
                  children: [
                    for (final o in stuck)
                      Card(
                        child: ListTile(
                          title: Text(
                            o.elderDisplayName ?? '長輩',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            ShopOrderStatus.orderStatusLabel(o.status),
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/shop/orders/${o.id}'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _hubLocationAssetsProvider =
    FutureProvider.autoDispose<List<LocationAsset>>((ref) async {
  return LocationPointsRepository().listAssets();
});

class _HubCommunityAnalyticsSection extends ConsumerWidget {
  const _HubCommunityAnalyticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(communityAnalyticsProvider(null));
    return analytics.when(
      loading: () => const LinearProgressIndicator(color: VolunteerHubAnalyticsTab.hubBlue),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '社區代購成效（近 ${a.periodDays} 天）',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _HubStatCard(
                    label: '發放完成率',
                    value: '${(a.completionRate * 100).toStringAsFixed(0)}%',
                    color: VolunteerHubAnalyticsTab.hubTeal,
                  ),
                  _HubStatCard(
                    label: '處理中位數(h)',
                    value: a.medianFulfillmentHours.toStringAsFixed(1),
                    color: Colors.blue.shade800,
                  ),
                  _HubStatCard(
                    label: '替代次數',
                    value: '${a.substituteCount}',
                    color: Colors.deepOrange,
                  ),
                ],
              ),
              if (a.topCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '熱門品類',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                for (final t in a.topCategories.take(5))
                  ListTile(
                    dense: true,
                    title: Text(t.name, style: const TextStyle(fontSize: 16)),
                    trailing: Text('${t.qty}', style: const TextStyle(fontSize: 16)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HubStatCard extends StatelessWidget {
  const _HubStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        color: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 16, color: color)),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubOrderLineChart extends StatelessWidget {
  const _HubOrderLineChart({required this.ordersByDay});

  final List<DayOrderCount> ordersByDay;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < ordersByDay.length; i++) {
      spots.add(FlSpot(i.toDouble(), ordersByDay[i].count.toDouble()));
    }
    final maxY = ordersByDay.isEmpty
        ? 5.0
        : (ordersByDay.map((e) => e.count).reduce((a, b) => a > b ? a : b) + 2)
            .toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= ordersByDay.length) {
                        return const SizedBox.shrink();
                      }
                      final d = ordersByDay[idx].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${d.month}/${d.day}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: VolunteerHubAnalyticsTab.hubTeal,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 5,
                      color: Colors.white,
                      strokeWidth: 2.5,
                      strokeColor: VolunteerHubAnalyticsTab.hubTeal,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: VolunteerHubAnalyticsTab.hubTeal.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubTop5BarChart extends StatelessWidget {
  const _HubTop5BarChart({required this.top5});

  final List<({String name, int qty})> top5;

  @override
  Widget build(BuildContext context) {
    final maxQty = top5.isEmpty
        ? 1.0
        : top5.map((e) => e.qty).reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: SizedBox(
          height: top5.length * 52.0 + 16,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.center,
              maxY: maxQty + 2,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 90,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= top5.length) return const SizedBox.shrink();
                      final name = top5[idx].name;
                      return Text(
                        name.length > 6 ? '${name.substring(0, 6)}…' : name,
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: false,
                getDrawingVerticalLine: (v) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < top5.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: top5[i].qty.toDouble(),
                        color: VolunteerHubAnalyticsTab.hubBlue,
                        width: 22,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
