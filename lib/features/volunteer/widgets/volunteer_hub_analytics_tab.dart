import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/admin/presentation/admin_providers.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';

const _kGreen = Color(0xFF2E7D32);
const _kGreenLight = Color(0xFFE8F5E9);
const _kGreenPale = Color(0xFFF1F8E9);
const _kBlue = Color(0xFF1565C0);
const _kTeal = Color(0xFF00695C);

/// 志工儀表板「數據總覽」：統計、圖表、待處理需求清單。
class VolunteerHubAnalyticsTab extends ConsumerWidget {
  const VolunteerHubAnalyticsTab({super.key, this.onGoShoppingList});

  /// 嵌入物資代購分區時，切換至「代購管理」Tab。
  final VoidCallback? onGoShoppingList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final orders = ref.watch(adminOrdersProvider);
    final chartAsync = ref.watch(adminChartDataProvider);

    return RefreshIndicator(
      color: _kGreen,
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
        ref.invalidate(adminOrdersProvider);
        ref.invalidate(adminChartDataProvider);
        ref.invalidate(communityAnalyticsProvider(null));
      },
      child: stats.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: _kGreen),
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
            _OverviewCard(
              stats: s,
              onGoShoppingList:
                  onGoShoppingList ?? () => context.push('/volunteer/shop-orders'),
            ),
            const SizedBox(height: 16),
            const _HubCommunityAnalyticsSection(),
            const SizedBox(height: 16),
            chartAsync.when(
              loading: () => const _SectionShell(
                title: '近 7 天需求趨勢',
                icon: Icons.show_chart,
                child: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(color: _kGreen)),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionShell(
                    title: '近 7 天需求趨勢',
                    icon: Icons.show_chart,
                    child: _HubOrderLineChart(ordersByDay: data.ordersByDay),
                  ),
                  const SizedBox(height: 16),
                  _SectionShell(
                    title: '熱門物資 Top5',
                    icon: Icons.leaderboard_outlined,
                    child: data.top5.isEmpty
                        ? const _EmptyHint(
                            icon: Icons.inventory_2_outlined,
                            message: '尚無物資資料',
                          )
                        : _HubTop5BarChart(top5: data.top5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionShell(
              title: '待處理需求',
              icon: Icons.assignment_late_outlined,
              child: orders.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => _VolunteerActionOrdersSection(
                  orders: list,
                  onOpenOrder: (id) => context.push('/shop/orders/$id'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.stats,
    required this.onGoShoppingList,
  });

  final AdminOrderStats stats;
  final VoidCallback onGoShoppingList;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: _kGreen.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kGreen, _kGreen.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '柑仔店數據總覽',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewSummaryStrip(
                  pending: stats.pendingCount,
                  processing: stats.processingCount,
                  active: stats.activeCount,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HubStatTile(
                        label: '總需求單',
                        value: '${stats.totalOrders}',
                        color: _kTeal,
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HubStatTile(
                        label: '已完成',
                        value: '${stats.completedCount}',
                        color: _kGreen,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onGoShoppingList,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('前往代購總清單', style: TextStyle(fontSize: 17)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreenLight,
                    foregroundColor: _kGreen,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSummaryStrip extends StatelessWidget {
  const _OverviewSummaryStrip({
    required this.pending,
    required this.processing,
    required this.active,
  });

  final int pending;
  final int processing;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              value: '$pending',
              label: '待接單',
              icon: Icons.hourglass_top_outlined,
              color: Colors.orange.shade800,
            ),
          ),
          _stripDivider(),
          Expanded(
            child: _MiniStat(
              value: '$processing',
              label: '已接單',
              icon: Icons.shopping_bag_outlined,
              color: _kBlue,
            ),
          ),
          _stripDivider(),
          Expanded(
            child: _MiniStat(
              value: '$active',
              label: '待處理',
              icon: Icons.pending_actions_outlined,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripDivider() => Container(
        width: 1,
        height: 36,
        color: _kGreen.withValues(alpha: 0.2),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _HubStatTile extends StatelessWidget {
  const _HubStatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: color),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: _kGreen.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: _kGreenPale,
            child: Row(
              children: [
                Icon(icon, color: _kGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _kGreen,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ElderOrderGroup {
  const _ElderOrderGroup({
    required this.elderKey,
    required this.elderName,
    required this.orders,
  });

  final String elderKey;
  final String elderName;
  final List<ShopOrderListRow> orders;

  bool get hasUrgent => orders.any((o) => o.isUrgent);
  int get pendingCount => orders.where((o) => o.status == 'pending').length;
  int get processingCount => orders.where((o) => o.status == 'processing').length;
}

class _VolunteerActionOrdersSection extends StatefulWidget {
  const _VolunteerActionOrdersSection({
    required this.orders,
    required this.onOpenOrder,
  });

  final List<ShopOrderListRow> orders;
  final ValueChanged<String> onOpenOrder;

  @override
  State<_VolunteerActionOrdersSection> createState() =>
      _VolunteerActionOrdersSectionState();
}

class _VolunteerActionOrdersSectionState
    extends State<_VolunteerActionOrdersSection> {
  final Set<String> _expandedElders = {};

  static bool _isActive(ShopOrderListRow o) =>
      o.status == 'pending' || o.status == 'processing';

  static String _elderName(ShopOrderListRow o) =>
      (o.elderDisplayName ?? '').trim().isEmpty
          ? '長輩'
          : o.elderDisplayName!.trim();

  static String _itemSummary(ShopOrderListRow o) {
    if (o.items.isEmpty) return '（無品項）';
    final names = o.items.map((i) => i.productName).where((n) => n.isNotEmpty);
    final joined = names.take(3).join('、');
    if (names.length > 3) return '$joined 等 ${o.items.length} 項';
    return joined;
  }

  static String _formatOrderDate(DateTime t) {
    final l = t.toLocal();
    return '${l.month}月${l.day}日';
  }

  static Color _statusColor(String status) => switch (status) {
        'pending' => Colors.orange.shade800,
        'processing' => _kBlue,
        _ => _kGreen,
      };

  List<_ElderOrderGroup> _buildElderGroups(List<ShopOrderListRow> active) {
    final byElder = <String, List<ShopOrderListRow>>{};
    for (final o in active) {
      byElder.putIfAbsent(o.userId, () => []).add(o);
    }

    final groups = byElder.entries.map((e) {
      final sorted = List<ShopOrderListRow>.from(e.value)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _ElderOrderGroup(
        elderKey: e.key,
        elderName: _elderName(sorted.first),
        orders: sorted,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.hasUrgent != b.hasUrgent) return a.hasUrgent ? -1 : 1;
      if (a.pendingCount != b.pendingCount) {
        return b.pendingCount.compareTo(a.pendingCount);
      }
      return a.elderName.compareTo(b.elderName);
    });
    return groups;
  }

  void _toggleElder(String key) {
    setState(() {
      if (_expandedElders.contains(key)) {
        _expandedElders.remove(key);
      } else {
        _expandedElders.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.orders.where(_isActive).toList();
    final groups = _buildElderGroups(active);

    if (groups.isEmpty) {
      return const _EmptyHint(
        icon: Icons.inbox_outlined,
        message: '目前沒有待處理的需求\n長輩送出後會顯示在這裡',
      );
    }

    final totalOrders = active.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kGreenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: _kGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '共 ${groups.length} 位長輩 · $totalOrders 筆需求',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final g = groups[index];
              final expanded = _expandedElders.contains(g.elderKey);
              return _ElderAvatarChip(
                name: g.elderName,
                orderCount: g.orders.length,
                hasUrgent: g.hasUrgent,
                selected: expanded,
                onTap: () => _toggleElder(g.elderKey),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        for (final g in groups)
          _ElderOrderGroupCard(
            group: g,
            expanded: _expandedElders.contains(g.elderKey),
            onToggle: () => _toggleElder(g.elderKey),
            itemSummary: _itemSummary,
            formatDate: _formatOrderDate,
            statusColor: _statusColor,
            onOpenOrder: widget.onOpenOrder,
          ),
      ],
    );
  }
}

class _ElderAvatarChip extends StatelessWidget {
  const _ElderAvatarChip({
    required this.name,
    required this.orderCount,
    required this.hasUrgent,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int orderCount;
  final bool hasUrgent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first : '長';
    final ringColor = selected ? _kGreen : Colors.grey.shade300;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: selected ? 2.5 : 1.5,
                      ),
                      color: selected
                          ? _kGreen.withValues(alpha: 0.08)
                          : Colors.white,
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: _kGreen.withValues(alpha: 0.12),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _kGreen,
                        ),
                      ),
                    ),
                  ),
                  if (hasUrgent)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _kGreen : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '$orderCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? _kGreen : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderOrderGroupCard extends StatelessWidget {
  const _ElderOrderGroupCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.itemSummary,
    required this.formatDate,
    required this.statusColor,
    required this.onOpenOrder,
  });

  final _ElderOrderGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(ShopOrderListRow) itemSummary;
  final String Function(DateTime) formatDate;
  final Color Function(String) statusColor;
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final initial =
        group.elderName.isNotEmpty ? group.elderName.characters.first : '長';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: expanded ? _kGreenPale : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded
                ? _kGreen.withValues(alpha: 0.35)
                : Colors.grey.shade200,
            width: expanded ? 1.5 : 1,
          ),
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _kGreen.withValues(alpha: 0.15),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.elderName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (group.hasUrgent)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE65100),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '緊急',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (group.pendingCount > 0)
                                  _MiniStatusPill(
                                    label: '待接單 ${group.pendingCount}',
                                    color: Colors.orange.shade800,
                                  ),
                                if (group.processingCount > 0)
                                  _MiniStatusPill(
                                    label: '已接單 ${group.processingCount}',
                                    color: _kBlue,
                                  ),
                                _MiniStatusPill(
                                  label: '共 ${group.orders.length} 筆',
                                  color: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: expanded ? _kGreen : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(height: 1, color: _kGreen.withValues(alpha: 0.15)),
                  for (var i = 0; i < group.orders.length; i++)
                    _ElderOrderDetailTile(
                      order: group.orders[i],
                      dateLabel: formatDate(group.orders[i].createdAt),
                      itemSummary: itemSummary(group.orders[i]),
                      statusColor: statusColor(group.orders[i].status),
                      isLast: i == group.orders.length - 1,
                      onTap: () => onOpenOrder(group.orders[i].id),
                    ),
                ],
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ElderOrderDetailTile extends StatelessWidget {
  const _ElderOrderDetailTile({
    required this.order,
    required this.dateLabel,
    required this.itemSummary,
    required this.statusColor,
    required this.isLast,
    required this.onTap,
  });

  final ShopOrderListRow order;
  final String dateLabel;
  final String itemSummary;
  final Color statusColor;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = ShopOrderStatus.orderStatusLabel(order.status);
    final location = (order.locationPointName ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, isLast ? 12 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '共 ${order.totalQuantity} 件',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        itemSummary,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCommunityAnalyticsSection extends ConsumerWidget {
  const _HubCommunityAnalyticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(communityAnalyticsProvider(null));
    return analytics.when(
      loading: () => const _SectionShell(
        title: '柑仔店成效',
        icon: Icons.insights_outlined,
        child: SizedBox(
          height: 48,
          child: Center(child: LinearProgressIndicator(color: _kGreen)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (a) => _SectionShell(
        title: '柑仔店成效（近 ${a.periodDays} 天）',
        icon: Icons.insights_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _HubStatTile(
                    label: '發放完成率',
                    value: '${(a.completionRate * 100).toStringAsFixed(0)}%',
                    color: _kTeal,
                    icon: Icons.task_alt_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HubStatTile(
                    label: '平均處理時數',
                    value: a.medianFulfillmentHours.toStringAsFixed(1),
                    color: _kBlue,
                    icon: Icons.schedule_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _HubStatTile(
              label: '替代次數',
              value: '${a.substituteCount}',
              color: Colors.deepOrange,
              icon: Icons.swap_horiz_outlined,
            ),
            if (a.topCategories.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '熱門品類',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kGreen,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < a.topCategories.take(5).length; i++)
                _CategoryBarRow(
                  rank: i + 1,
                  name: a.topCategories[i].name,
                  qty: a.topCategories[i].qty,
                  maxQty: a.topCategories.first.qty,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  const _CategoryBarRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.maxQty,
  });

  final int rank;
  final String name;
  final int qty;
  final int maxQty;

  @override
  Widget build(BuildContext context) {
    final ratio = maxQty > 0 ? qty / maxQty : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _kBlue.withValues(alpha: 0.12),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: Colors.grey.shade200,
                    color: _kBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '× $qty',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

    return SizedBox(
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
              color: _kGreen,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: _kGreen,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _kGreen.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTop5BarChart extends StatelessWidget {
  const _HubTop5BarChart({required this.top5});

  final List<({String name, int qty})> top5;

  static String _shortLabel(String name, {int max = 10}) {
    final t = name.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static void _showFullName(BuildContext context, String name, int qty) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '物資名稱',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          name,
          style: const TextStyle(fontSize: 18, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('關閉（共 $qty 件）', style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxQty = top5.isEmpty
        ? 1
        : top5.map((e) => e.qty).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < top5.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < top5.length - 1 ? 8 : 0),
            child: Material(
              color: _kBlue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showFullName(context, top5[i].name, top5[i].qty),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _kBlue,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortLabel(top5[i].name),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              '點一下看全名',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: top5[i].qty / maxQty,
                            backgroundColor: Colors.grey.shade200,
                            color: _kBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '× ${top5[i].qty}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
