import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/admin/presentation/admin_providers.dart';
import 'package:smart_bp/features/shop/data/location_points_repository.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';

/// 管理後台：物資訂單統計與滯留單（畢專展示用）。
final _adminLocationAssetsProvider =
    FutureProvider.autoDispose<List<LocationAsset>>((ref) async {
  return ref.read(locationPointsRepositoryProvider).listAssets();
});

final locationPointsRepositoryProvider =
    Provider<LocationPointsRepository>((ref) => const LocationPointsRepository());

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  static const Color _adminTeal = Color(0xFF00695C);
  static const Color _cream = Color(0xFFFFF8E1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final orders = ref.watch(adminOrdersProvider);
    final assetsAsync = ref.watch(_adminLocationAssetsProvider);
    final chartAsync = ref.watch(adminChartDataProvider);

    return RoleGuard(
      requiredRole: RoleGuardTarget.admin,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _adminTeal,
          foregroundColor: Colors.white,
          title: const Text('物資管理後台', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(adminStatsProvider);
                ref.invalidate(adminOrdersProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
          ],
        ),
        body: stats.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _adminTeal)),
          error: (e, _) => Center(child: Text('載入失敗：$e\n請確認 profiles.role=admin 且已執行 SQL')),
          data: (s) {
            return RefreshIndicator(
              color: _adminTeal,
                    onRefresh: () async {
                        ref.invalidate(adminStatsProvider);
                        ref.invalidate(adminOrdersProvider);
                        ref.invalidate(adminChartDataProvider);
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(label: '總需求單', value: '${s.totalOrders}', color: _adminTeal),
                      _StatCard(label: '待處理', value: '${s.pendingCount}', color: Colors.orange.shade800),
                      _StatCard(label: '處理中', value: '${s.processingCount}', color: Colors.blue.shade800),
                      _StatCard(label: '已完成', value: '${s.completedCount}', color: Colors.green.shade800),
                      _StatCard(label: '滯留>24h', value: '${s.stuckCount}', color: Colors.red.shade700),
                      _StatCard(label: '需求草稿', value: '${s.draftDemandCount}', color: Colors.deepPurple),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── 圖表區塊 ──
                  chartAsync.when(
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: _adminTeal)),
                    ),
                    error: (_, e) => const SizedBox.shrink(),
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '近 7 天訂單趨勢',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _OrderLineChart(ordersByDay: data.ordersByDay),
                        const SizedBox(height: 20),
                        const Text(
                          '熱門品項 Top5',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (data.top5.isEmpty)
                          const Card(child: ListTile(title: Text('尚無品項資料')))
                        else
                          _Top5BarChart(top5: data.top5),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('據點物品管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  assetsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      '讀取據點物品失敗：$e\n請執行 chapter5_shop_assistant_schema.sql',
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
                  const Text('近期滯留訂單', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  orders.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
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
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 近 7 天訂單折線圖
// ────────────────────────────────────────────────────────────────────────────
class _OrderLineChart extends StatelessWidget {
  const _OrderLineChart({required this.ordersByDay});

  final List<DayOrderCount> ordersByDay;

  static const Color _lineColor = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < ordersByDay.length; i++) {
      spots.add(FlSpot(i.toDouble(), ordersByDay[i].count.toDouble()));
    }
    final maxY = ordersByDay.isEmpty
        ? 5.0
        : (ordersByDay.map((e) => e.count).reduce((a, b) => a > b ? a : b) + 2).toDouble();

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
                horizontalInterval: 1,
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
                      if (idx < 0 || idx >= ordersByDay.length) return const SizedBox.shrink();
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
                  color: _lineColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 5,
                      color: Colors.white,
                      strokeWidth: 2.5,
                      strokeColor: _lineColor,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _lineColor.withValues(alpha: 0.08),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (pts) => pts
                      .map((p) => LineTooltipItem(
                            '${p.y.toInt()} 筆',
                            const TextStyle(color: Colors.white, fontSize: 14),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Top5 品項橫條圖
// ────────────────────────────────────────────────────────────────────────────
class _Top5BarChart extends StatelessWidget {
  const _Top5BarChart({required this.top5});

  final List<({String name, int qty})> top5;

  @override
  Widget build(BuildContext context) {
    final maxQty = top5.isEmpty
        ? 1.0
        : top5.map((e) => e.qty).reduce((a, b) => a > b ? a : b).toDouble();
    const barColor = Color(0xFF1565C0);

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
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gIdx, rod, rIdx) => BarTooltipItem(
                    '${rod.toY.toInt()} 件',
                    const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
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
                        color: barColor,
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

// ────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

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
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
