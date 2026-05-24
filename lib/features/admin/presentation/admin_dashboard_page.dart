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
                  const Text('熱門品項 Top5', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        if (s.hotProducts.isEmpty)
                          const ListTile(title: Text('尚無資料'))
                        else
                          ...[
                            for (final p in s.hotProducts)
                              ListTile(
                                title: Text(p.name, style: const TextStyle(fontSize: 18)),
                                trailing: Text(
                                  '× ${p.qty}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
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
