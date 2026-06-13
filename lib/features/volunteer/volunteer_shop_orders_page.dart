import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/shared/debug/realtime_latency_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/px_mart_links.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_procurement_summary_sheet.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_daily_shopping_list_panel.dart';
import 'package:smart_bp/features/shared/elder_phone_utils.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_shop_confirm_dialog.dart';
import 'package:url_launcher/url_launcher.dart';


/// 志工端：全聯／柑仔店代購需求單列表。
class VolunteerShopOrdersPage extends ConsumerStatefulWidget {
  const VolunteerShopOrdersPage({super.key, this.embedded = false});

  /// 嵌入志工主控台時為 true，不另包 [Scaffold]／[AppBar]。
  final bool embedded;

  static const Color _volunteerBlue = Color(0xFF1565C0);
  static const Color _backgroundCream = Color(0xFFFFF8E1);

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'pending' => '待接單',
      'processing' => '已接單',
      'completed' => '完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  @override
  ConsumerState<VolunteerShopOrdersPage> createState() => _VolunteerShopOrdersPageState();
}

enum _OrderViewFilter { active, history }

class _VolunteerShopOrdersPageState extends ConsumerState<VolunteerShopOrdersPage> {
  _OrderViewFilter _filter = _OrderViewFilter.active;
  final Set<String> _expandedSteps = {};
  final Set<String> _expandedHistorySteps = {};

  static const _stepPending = '待接單';
  static const _stepAccepted = '已接單';
  static const _stepComplete = '完成採購';
  static const _stepDone = '完成';
  static const _stepCancelled = '已取消';

  static bool _isActive(ShopOrderListRow o) => o.status == 'pending' || o.status == 'processing';
  static bool _isHistory(ShopOrderListRow o) => o.status == 'completed' || o.status == 'cancelled';

  static List<ShopOrderListRow> _sortOrders(List<ShopOrderListRow> orders) {
    final sorted = orders.toList();
    sorted.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  static Map<String, List<ShopOrderListRow>> _groupByStatusBucket(
    List<ShopOrderListRow> orders,
  ) {
    final map = <String, List<ShopOrderListRow>>{};
    for (final o in orders) {
      final key = _statusBucketLabel(o);
      map.putIfAbsent(key, () => []).add(o);
    }
    const order = [_stepPending, _stepAccepted];
    return {
      for (final k in order)
        if (map.containsKey(k)) k: map[k]!,
    };
  }

  static String _statusBucketLabel(ShopOrderListRow o) {
    if (o.status == 'pending') return _stepPending;
    if (o.status == 'processing') return _stepAccepted;
    return VolunteerShopOrdersPage._statusLabel(o.status);
  }

  void _toggleStep(String step) {
    setState(() {
      if (_expandedSteps.contains(step)) {
        _expandedSteps.remove(step);
      } else {
        _expandedSteps.add(step);
      }
    });
  }

  void _toggleHistoryStep(String step) {
    setState(() {
      if (_expandedHistorySteps.contains(step)) {
        _expandedHistorySteps.remove(step);
      } else {
        _expandedHistorySteps.add(step);
      }
    });
  }

  static int _totalItemQty(List<ShopOrderListRow> orders) =>
      orders.fold<int>(0, (sum, o) => sum + o.totalQuantity);

  Future<void> _acceptAllPending(
    BuildContext context,
    List<ShopOrderListRow> pending,
  ) async {
    final vid = Supabase.instance.client.auth.currentUser?.id;
    if (vid == null || pending.isEmpty) return;

    final ok = await VolunteerProcurementSummarySheet.showPreviewBeforeAccept(
      context,
      orders: pending,
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在接單…')),
    );

    final result = await ref.read(shopOrdersRepositoryProvider).acceptPendingOrdersByVolunteer(
          volunteerId: vid,
          orderIds: pending.map((o) => o.id).toList(),
        );

    if (!context.mounted) return;
    ref.invalidate(shopVolunteerOrdersProvider);
    ref.invalidate(volunteerShoppingLocationsProvider);

    if (result.failed == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('已全部接單（${result.accepted} 筆）')),
      );
      await VolunteerProcurementSummarySheet.showAfterAccept(
        context,
        orders: pending,
        acceptedCount: result.accepted,
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '已接單 ${result.accepted} 筆，${result.failed} 筆失敗請稍後重試',
          ),
        ),
      );
    }
  }

  Future<void> _completeSingleOrder(
    BuildContext context,
    ShopOrderListRow order,
  ) async {
    final elderName = _elderDisplayName(order);
    final itemSummary = _orderItemSummary(order);

    final ok = await VolunteerShopConfirmDialog.confirmCompleteDelivery(
      context,
      elderName: elderName,
      itemSummary: itemSummary,
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shopOrdersRepositoryProvider).completeDelivery(orderId: order.id);
      if (!context.mounted) return;
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(volunteerShoppingLocationsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('已完成 $elderName 的代購，已通知長輩')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('完成採購失敗：$e')));
    }
  }

  static String _elderDisplayName(ShopOrderListRow order) {
    final name = (order.elderDisplayName ?? '').trim();
    if (name.isNotEmpty) return name;
    return '長輩 ${order.userId.substring(0, 8)}…';
  }

  static String _orderItemSummary(ShopOrderListRow order) {
    if (order.items.isEmpty) return '（無品項）';
    final parts = order.items.take(4).map((it) {
      final unit = (it.unitLabel ?? '').trim();
      return unit.isEmpty
          ? '${it.productName}×${it.quantity}'
          : '${it.productName}×${it.quantity}$unit';
    });
    final text = parts.join('、');
    if (order.items.length > 4) return '$text 等${order.items.length}項';
    return text;
  }

  Future<void> _completeAllProcessing(
    BuildContext context,
    List<ShopOrderListRow> processing,
  ) async {
    if (processing.isEmpty) return;

    final ok = await VolunteerShopConfirmDialog.confirmBatchCompleteDelivery(
      context,
      orders: processing,
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在完成採購…')));

    try {
      final updated = await ref
          .read(shopOrdersRepositoryProvider)
          .batchCompleteDeliveries(processing);
      if (!context.mounted) return;
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(volunteerShoppingLocationsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('已完成 $updated 筆，已通知長輩物資送達活動中心'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('完成採購失敗：$e')));
    }
  }

  Widget _buildActiveStepPanels({
    required List<ShopOrderListRow> orders,
    required List<ShopOrderListRow> pendingOrders,
    required List<ShopOrderListRow> processingOrders,
    String? summaryLabel,
  }) {
    final totalQty = _totalItemQty(orders);
    final grouped = _groupByStatusBucket(orders);
    final headline = summaryLabel ??
        '共 ${orders.length} 筆進行中 · $totalQty 件物資';

    return Card(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (summaryLabel == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    CommunityProcurementDay.homeLine(),
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
          _DemandStepTile(
            step: _stepPending,
            count: pendingOrders.length,
            color: Colors.orange.shade800,
            expanded: _expandedSteps.contains(_stepPending),
            onToggle: () => _toggleStep(_stepPending),
            children: [
              if (pendingOrders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: FilledButton.icon(
                    onPressed: () => _acceptAllPending(context, pendingOrders),
                    icon: const Icon(Icons.done_all),
                    label: Text(
                      '全部接單（${pendingOrders.length} 筆）',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ),
              for (final o in grouped[_stepPending] ?? const [])
                _OrderCard(order: o),
            ],
          ),
          _DemandStepTile(
            step: _stepAccepted,
            count: processingOrders.length,
            color: Colors.blue.shade800,
            expanded: _expandedSteps.contains(_stepAccepted),
            onToggle: () => _toggleStep(_stepAccepted),
            children: [
              for (final o in grouped[_stepAccepted] ?? const [])
                _OrderCard(order: o),
            ],
          ),
          if (processingOrders.isNotEmpty)
            _DemandStepTile(
              step: _stepComplete,
              count: processingOrders.length,
              color: Colors.green.shade800,
              expanded: _expandedSteps.contains(_stepComplete),
              onToggle: () => _toggleStep(_stepComplete),
              children: [
                for (final o in processingOrders)
                  _CompleteProcurementRow(
                    order: o,
                    onComplete: () => _completeSingleOrder(context, o),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: FilledButton.icon(
                    onPressed: () =>
                        _completeAllProcessing(context, processingOrders),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      '全部完成採購（${processingOrders.length} 筆）',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanels(List<ShopOrderListRow> orders) {
    final completed =
        orders.where((o) => o.status == 'completed').toList();
    final cancelled =
        orders.where((o) => o.status == 'cancelled').toList();

    return Card(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${orders.length} 筆已完成 · ${_totalItemQty(orders)} 件物資',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (completed.isNotEmpty)
                      _SummaryChip(
                        label: _stepDone,
                        count: completed.length,
                        color: Colors.green.shade800,
                      ),
                    if (cancelled.isNotEmpty)
                      _SummaryChip(
                        label: _stepCancelled,
                        count: cancelled.length,
                        color: Colors.grey.shade700,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (completed.isNotEmpty)
            _DemandStepTile(
              step: _stepDone,
              count: completed.length,
              color: Colors.green.shade800,
              expanded: _expandedHistorySteps.contains(_stepDone),
              onToggle: () => _toggleHistoryStep(_stepDone),
              children: [
                for (final o in completed) _CompactOrderRow(order: o),
              ],
            ),
          if (cancelled.isNotEmpty)
            _DemandStepTile(
              step: _stepCancelled,
              count: cancelled.length,
              color: Colors.grey.shade700,
              expanded: _expandedHistorySteps.contains(_stepCancelled),
              onToggle: () => _toggleHistoryStep(_stepCancelled),
              children: [
                for (final o in cancelled) _CompactOrderRow(order: o),
              ],
            ),
        ],
      ),
    );
  }

  void _refreshOrders() {
    ref.invalidate(shopVolunteerOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopVolunteerOrdersProvider);

    final content = Stack(
      children: [
        SafeArea(
          top: !widget.embedded,
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: VolunteerShopOrdersPage._volunteerBlue),
            ),
            error: (e, _) => _ErrorBody(
              message: '讀取需求單失敗：$e',
              onRetry: _refreshOrders,
            ),
            data: (orders) {
              final activeCount = orders.where(_isActive).length;
              final historyCount = orders.where(_isHistory).length;
              final activeOrders =
                  _sortOrders(orders.where(_isActive).toList());
              final historyOrders =
                  _sortOrders(orders.where(_isHistory).toList());
              final pendingOrders =
                  activeOrders.where((o) => o.status == 'pending').toList();
              final processingOrders =
                  activeOrders.where((o) => o.status == 'processing').toList();

              Widget mainPanel;
              if (orders.isEmpty) {
                mainPanel = const _FilterEmptyCard(
                  message: '尚無柑仔店需求單\n長輩送出後會出現在此',
                );
              } else {
                switch (_filter) {
                  case _OrderViewFilter.active:
                    mainPanel = activeOrders.isEmpty
                        ? const _FilterEmptyCard(message: '尚無進行中需求')
                        : _buildActiveStepPanels(
                            orders: activeOrders,
                            pendingOrders: pendingOrders,
                            processingOrders: processingOrders,
                          );
                  case _OrderViewFilter.history:
                    mainPanel = historyOrders.isEmpty
                        ? const _FilterEmptyCard(message: '尚無已完成紀錄')
                        : _buildHistoryPanels(historyOrders);
                }
              }

              return RefreshIndicator(
                color: VolunteerShopOrdersPage._volunteerBlue,
                onRefresh: () async {
                  _refreshOrders();
                  await ref.read(shopVolunteerOrdersProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (widget.embedded) ...[
                      const Text(
                        '代購需求',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildHeader(
                      context,
                      activeCount: activeCount,
                      historyCount: historyCount,
                    ),
                    const SizedBox(height: 12),
                    mainPanel,
                    if (_filter == _OrderViewFilter.active &&
                        orders.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const VolunteerDailyShoppingListPanel(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (kDebugMode) const RealtimeLatencyBanner(),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: VolunteerShopOrdersPage._backgroundCream,
        child: content,
      );
    }

    return RoleGuard(
      requiredRole: RoleGuardTarget.volunteer,
      child: Scaffold(
        backgroundColor: VolunteerShopOrdersPage._backgroundCream,
        appBar: AppBar(
          backgroundColor: VolunteerShopOrdersPage._volunteerBlue,
          foregroundColor: Colors.white,
          title: const Text(
            '柑仔店',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh, size: 28),
              onPressed: _refreshOrders,
            ),
          ],
        ),
        body: content,
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int activeCount,
    required int historyCount,
  }) {
    return _OrderFilterBar(
      selected: _filter,
      activeCount: activeCount,
      historyCount: historyCount,
      onSelected: (next) => setState(() => _filter = next),
    );
  }
}

class _OrderFilterBar extends StatelessWidget {
  const _OrderFilterBar({
    required this.selected,
    required this.activeCount,
    required this.historyCount,
    required this.onSelected,
  });

  final _OrderViewFilter selected;
  final int activeCount;
  final int historyCount;
  final ValueChanged<_OrderViewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _FilterTab(
                label: '進行中',
                count: activeCount,
                selected: selected == _OrderViewFilter.active,
                onTap: () => onSelected(_OrderViewFilter.active),
              ),
            ),
            Expanded(
              child: _FilterTab(
                label: '已完成',
                count: historyCount,
                selected: selected == _OrderViewFilter.history,
                onTap: () => onSelected(_OrderViewFilter.history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _green.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected ? _green : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? _green : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterEmptyCard extends StatelessWidget {
  const _FilterEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _CompactOrderRow extends StatelessWidget {
  const _CompactOrderRow({required this.order});

  final ShopOrderListRow order;

  @override
  Widget build(BuildContext context) {
    final elderName = _VolunteerShopOrdersPageState._elderDisplayName(order);
    final itemSummary = _VolunteerShopOrdersPageState._orderItemSummary(order);
    final statusLabel = VolunteerShopOrdersPage._statusLabel(order.status);
    final time = VolunteerShopOrdersPage._formatTime(order.createdAt);
    final statusColor = switch (order.status) {
      'completed' => Colors.green.shade800,
      'cancelled' => Colors.grey.shade700,
      _ => Colors.blue.shade800,
    };
    final initial =
        elderName.isNotEmpty ? elderName.characters.first : '長';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _CompactOrderDetailSheet.show(context, order),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
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
                              elderName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (order.isUrgent)
                            Container(
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
                      Text(
                        itemSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$time · $statusLabel · 共 ${order.totalQuantity} 件',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactOrderDetailSheet {
  static Future<void> show(BuildContext context, ShopOrderListRow order) {
    final elderName = _VolunteerShopOrdersPageState._elderDisplayName(order);
    final statusLabel = VolunteerShopOrdersPage._statusLabel(order.status);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  elderName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${VolunteerShopOrdersPage._formatTime(order.createdAt)} · $statusLabel · 共 ${order.totalQuantity} 件',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                if (order.userId.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => VolunteerShopConfirmDialog.launchTelForElder(
                      ctx,
                      elderUserId: order.userId,
                      fallbackPhone: order.elderPhone,
                    ),
                    icon: const Icon(Icons.call),
                    label: Text(
                      '致電 ${ElderPhoneUtils.formatForDisplay(order.elderPhone) ?? '長輩'}',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  '代購品項',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final item in order.items)
                  _OrderItemTile(item: item),
              ],
            );
          },
        );
      },
    );
  }
}

class _DemandStepTile extends StatelessWidget {
  const _DemandStepTile({
    required this.step,
    required this.count,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String step;
  final int count;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('demand-step-$step-$expanded'),
        initiallyExpanded: expanded,
        onExpansionChanged: (isExpanded) {
          if (isExpanded != expanded) onToggle();
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        title: Text(
          step,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _CompleteProcurementRow extends StatelessWidget {
  const _CompleteProcurementRow({
    required this.order,
    required this.onComplete,
  });

  final ShopOrderListRow order;
  final VoidCallback onComplete;

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final elderName = _VolunteerShopOrdersPageState._elderDisplayName(order);
    final itemSummary = _VolunteerShopOrdersPageState._orderItemSummary(order);
    final initial =
        elderName.isNotEmpty ? elderName.characters.first : '長';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _green.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      elderName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemSummary,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '共 ${order.totalQuantity} 件',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.tonal(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: const Text(
                  '完成',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final ShopOrderListRow order;

  static const Color _green = Color(0xFF2E7D32);

  Future<void> _callElder(BuildContext context) async {
    await VolunteerShopConfirmDialog.launchTelForElder(
      context,
      elderUserId: order.userId,
      fallbackPhone: order.elderPhone,
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String newStatus,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shopOrdersRepositoryProvider).updateOrderStatusByVolunteer(
            orderId: order.id,
            currentStatus: order.status,
            newStatus: newStatus,
          );
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('已更新為：${VolunteerShopOrdersPage._statusLabel(newStatus)}')));
      ref.invalidate(shopVolunteerOrdersProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('更新失敗，請稍後再試。'),
        ),
      );
    }
  }

  Future<void> _acceptOrder(BuildContext context, WidgetRef ref) async {
    final vid = Supabase.instance.client.auth.currentUser?.id;
    if (vid == null) return;
    try {
      await ref.read(shopOrdersRepositoryProvider).acceptOrderByVolunteer(
            orderId: order.id,
            volunteerId: vid,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已接單 · ${CommunityProcurementDay.elderAcceptNotice()}')),
      );
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(volunteerShoppingLocationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('接單失敗：$e')));
    }
  }

  Future<void> _completeOrder(BuildContext context, WidgetRef ref) async {
    final elderName = _VolunteerShopOrdersPageState._elderDisplayName(order);
    final itemSummary = _VolunteerShopOrdersPageState._orderItemSummary(order);

    final ok = await VolunteerShopConfirmDialog.confirmCompleteDelivery(
      context,
      elderName: elderName,
      itemSummary: itemSummary,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(shopOrdersRepositoryProvider).completeDelivery(orderId: order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已完成 $elderName 的代購，已通知長輩')),
      );
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(volunteerShoppingLocationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('完成採購失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = order.elderDisplayName != null && order.elderDisplayName!.isNotEmpty
        ? order.elderDisplayName!
        : '長輩 ${order.userId.substring(0, 8)}…';

    final itemPreview = order.items
        .take(3)
        .map((it) => it.productName)
        .join('、');
    final itemSuffix =
        order.items.length > 3 ? ' 等${order.items.length}項' : '';

    final statusLine = '${VolunteerShopOrdersPage._formatTime(order.createdAt)} · '
        '${VolunteerShopOrdersPage._statusLabel(order.status)} · '
        '共 ${order.totalQuantity} 件'
        '${order.totalAmount != null ? ' · 參考總額 ${order.totalAmount} 元' : ''}'
        '${itemPreview.isNotEmpty ? '\n$itemPreview$itemSuffix' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: order.isUrgent
            ? const BorderSide(color: Color(0xFFE65100), width: 2)
            : BorderSide.none,
      ),
      color: order.isUrgent ? const Color(0xFFFFF8F5) : null,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          title: Row(
            children: [
              if (order.isUrgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency, size: 14, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        '緊急',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              statusLine,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ),
          children: [
            if (order.elderPhone != null && order.elderPhone!.trim().isNotEmpty)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFF1565C0)),
                title: Text(
                  '聯絡電話：${ElderPhoneUtils.formatForDisplay(order.elderPhone) ?? order.elderPhone}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _callElder(context),
                  icon: const Icon(Icons.call, size: 22),
                  label: const Text('致電長輩', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (order.status == 'pending')
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('確認接單？'),
                          content: Text(
                            '接單後改為「已接單」，並通知長輩將於${CommunityProcurementDay.nextProcurementShort()}代買。',
                            style: TextStyle(fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('先不要'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                              ),
                              child: const Text('確認接單'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await _acceptOrder(context, ref);
                      }
                    },
                    icon: const Icon(Icons.shopping_cart_checkout, size: 22),
                    label: const Text('接單', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                if (order.status == 'processing') ...[
                  FilledButton.icon(
                    onPressed: () => _completeOrder(context, ref),
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('完成採購', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('退回待接單？'),
                          content: const Text(
                            '需求單將恢復為「待接單」。',
                            style: TextStyle(fontSize: 16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('確定退回'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await _setStatus(context, ref, 'pending');
                      }
                    },
                    icon: const Icon(Icons.undo, size: 22),
                    label: const Text('退回待接單', style: TextStyle(fontSize: 16)),
                  ),
                ],
                if (order.status == 'pending' || order.status == 'processing')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('取消此需求？'),
                          content: const Text('請先與長輩確認後再取消。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('確定取消')),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await _setStatus(context, ref, 'cancelled');
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 22),
                    label: const Text('取消需求', style: TextStyle(fontSize: 16)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (order.note != null && order.note!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '備註：${order.note}',
                    style: const TextStyle(fontSize: 17, height: 1.35),
                  ),
                ),
              ),
            for (final it in order.items)
              _OrderItemTile(item: it),
            const SizedBox(height: 4),
            SelectableText(
              '需求單編號：${order.id}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/shop/orders/${order.id}'),
              icon: const Icon(Icons.timeline),
              label: const Text('配送時間軸', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 志工端：單一品項列（顯示名稱/數量/單位/分類 + 前往全聯搜尋按鈕）。
class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final ShopOrderItemRow item;

  Future<void> _openPxSearch(BuildContext context) async {
    final uri = buildPxMartUriFromName(item.productName);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯電商，請稍後再試')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitPart = item.unitLabel != null && item.unitLabel!.isNotEmpty
        ? ' ${item.unitLabel}'
        : '';
    final qtyText = '× ${item.quantity}$unitPart';
    final categoryText = item.category != null && item.category!.isNotEmpty
        ? '  ·  ${item.category}'
        : '';
    final priceText = item.unitPrice != null
        ? '  ·  參考單價 ${item.unitPrice!.toStringAsFixed(0)} 元'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    ElderSupplyTemplates.displayBrandLabel(item.brand),
                    item.productName,
                    if (item.spec != null && item.spec!.trim().isNotEmpty)
                      item.spec!.trim(),
                  ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · '),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qtyText$categoryText$priceText',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                if (item.referenceNote != null &&
                    item.referenceNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '備註：${item.referenceNote!.trim()}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _openPxSearch(context),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('全聯搜尋', style: TextStyle(fontSize: 14)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.error_outline, size: 64, color: Color(0xFFBF360C)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, height: 1.45),
        ),
        const SizedBox(height: 12),
        Text(
          '請確認網路連線正常，並以志工帳號登入後重試。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重試'),
        ),
      ],
    );
  }
}
