import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/presentation/volunteer_demands_provider.dart';
import 'package:smart_bp/shared/debug/realtime_latency_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/px_mart_links.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shopping_line_tile.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_daily_shopping_list_panel.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_purchase_batch_panel.dart';
import 'package:url_launcher/url_launcher.dart';


/// 志工端：全聯／柑仔店參考需求單列表（Supabase）。
class VolunteerShopOrdersPage extends ConsumerStatefulWidget {
  const VolunteerShopOrdersPage({super.key, this.embedded = false});

  /// 嵌入志工端主畫面「商城」分區時為 true，不另包 RoleGuard／Scaffold／AppBar。
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
      'pending' => '待處理',
      'processing' => '處理中（已接單）',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  @override
  ConsumerState<VolunteerShopOrdersPage> createState() => _VolunteerShopOrdersPageState();
}

enum _OrderViewFilter { active, history, all }

class _VolunteerShopOrdersPageState extends ConsumerState<VolunteerShopOrdersPage> {
  _OrderViewFilter _filter = _OrderViewFilter.active;
  final _loadingDraftIds = <String>{};

  static bool _isActive(ShopOrderListRow o) => o.status == 'pending' || o.status == 'processing';
  static bool _isHistory(ShopOrderListRow o) => o.status == 'completed' || o.status == 'cancelled';

  /// 志工接受草稿 → 轉為正式訂單 → 刷新兩端 Realtime。
  Future<void> _acceptDraft(DemandRecord draft) async {
    if (draft.activeItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此草稿沒有有效品項，無法轉為訂單')),
      );
      return;
    }
    setState(() => _loadingDraftIds.add(draft.id));
    try {
      await ref.read(demandRecordsRepositoryProvider).submitDraftToOrders(
            userId: draft.userId,
            ordersRepo: ref.read(shopOrdersRepositoryProvider),
          );
      ref.invalidate(volunteerDemandDraftsProvider);
      ref.invalidate(shopVolunteerOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(
            '已將「${draft.activeItems.map((i) => i.productName).join("、")}」轉為正式訂單',
            style: const TextStyle(fontSize: 17),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text(
            '接單失敗：$e\n請確認志工帳號有寫入 demand_records 的權限（RLS policy）',
            style: const TextStyle(fontSize: 16),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingDraftIds.remove(draft.id));
    }
  }

  List<ShopOrderListRow> _applyFilter(List<ShopOrderListRow> orders) {
    final filtered = switch (_filter) {
      _OrderViewFilter.active => orders.where(_isActive).toList(),
      _OrderViewFilter.history => orders.where(_isHistory).toList(),
      _OrderViewFilter.all => orders.toList(),
    };
    // 緊急優先；同緊急程度再按建立時間新→舊
    filtered.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  static Map<String, List<ShopOrderListRow>> _groupByLocation(
    List<ShopOrderListRow> orders,
  ) {
    final map = <String, List<ShopOrderListRow>>{};
    for (final o in orders) {
      final key = (o.locationPointName ?? '').trim().isEmpty
          ? '未指定據點'
          : o.locationPointName!.trim();
      map.putIfAbsent(key, () => []).add(o);
    }
    // 有緊急訂單的據點排最前面
    final keys = map.keys.toList()
      ..sort((a, b) {
        final aUrgent = map[a]!.any((o) => o.isUrgent) ? 0 : 1;
        final bUrgent = map[b]!.any((o) => o.isUrgent) ? 0 : 1;
        if (aUrgent != bUrgent) return aUrgent.compareTo(bUrgent);
        return a.compareTo(b);
      });
    return {for (final k in keys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopVolunteerOrdersProvider);
    final drafts = ref.watch(volunteerDemandDraftsProvider);

    final body = Stack(
          children: [
            SafeArea(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: VolunteerShopOrdersPage._volunteerBlue),
            ),
            error: (e, _) => _ErrorBody(
              message: '讀取需求單失敗：$e',
              onRetry: () => ref.invalidate(shopVolunteerOrdersProvider),
            ),
            data: (orders) {
              final filtered = _applyFilter(orders);
              final grouped = _groupByLocation(filtered);
              if (filtered.isEmpty &&
                  drafts.maybeWhen(data: (d) => d.isEmpty, orElse: () => true)) {
                return _EmptyBody(
                  onRefresh: () => ref.invalidate(shopVolunteerOrdersProvider),
                );
              }
              return RefreshIndicator(
                color: VolunteerShopOrdersPage._volunteerBlue,
                onRefresh: () async {
                  ref.invalidate(shopVolunteerOrdersProvider);
                  ref.invalidate(volunteerDemandDraftsProvider);
                  ref.invalidate(shopVolunteerOrdersProvider);
                  await ref.read(shopVolunteerOrdersProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildHeader(context),
                    const VolunteerDailyShoppingListPanel(),
                    const SizedBox(height: 12),
                    // 批次／路線為 v2 進階模組，v3 主流程不展示
                    if (kDebugMode) const VolunteerPurchaseBatchPanel(),
                    const SizedBox(height: 12),
                    drafts.when(
                      data: (list) {
                        if (list.isEmpty) return const SizedBox.shrink();
                        final byLoc = <String, List<DemandRecord>>{};
                        for (final d in list) {
                          final k = (d.locationName ?? '').trim().isEmpty
                              ? '未指定據點'
                              : d.locationName!.trim();
                          byLoc.putIfAbsent(k, () => []).add(d);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              '語音／小幫手草稿需求（依據點）',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final e in byLoc.entries)
                              ExpansionTile(
                                initiallyExpanded: true,
                                title: Text(
                                  '${e.key}（${e.value.length} 筆草稿）',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                children: [
                                  for (final d in e.value)
                                    _DraftCard(
                                      draft: d,
                                      isLoading: _loadingDraftIds.contains(d.id),
                                      onAccept: () => _acceptDraft(d),
                                    ),
                                ],
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, e) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '已送出訂單（依據點）',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in grouped.entries)
                      ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(
                          '${entry.key}（${entry.value.length} 筆）',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          for (final o in entry.value) _OrderCard(order: o),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
            // Debug-only Realtime 延遲量測 banner
            if (kDebugMode) const RealtimeLatencyBanner(),
          ],
        );

    if (widget.embedded) return body;

    return RoleGuard(
      requiredRole: RoleGuardTarget.volunteer,
      child: Scaffold(
        backgroundColor: VolunteerShopOrdersPage._backgroundCream,
        appBar: AppBar(
          backgroundColor: VolunteerShopOrdersPage._volunteerBlue,
          foregroundColor: Colors.white,
          title: const Text(
            '物資／今日採買',
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
              onPressed: () => ref.invalidate(shopVolunteerOrdersProvider),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: VolunteerShopOrdersPage._volunteerBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '以下為長輩從「柑仔店」送出的參考需求；價格以全聯門市／官網為準。若看不到姓名，請在 Supabase 為志工加上讀取 profiles 的 policy（見 orders_schema.sql 註解）。',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<_OrderViewFilter>(
            segments: const [
              ButtonSegment(
                value: _OrderViewFilter.active,
                label: Text('進行中'),
                icon: Icon(Icons.incomplete_circle_outlined),
              ),
              ButtonSegment(
                value: _OrderViewFilter.history,
                label: Text('歷史'),
                icon: Icon(Icons.history),
              ),
              ButtonSegment(
                value: _OrderViewFilter.all,
                label: Text('全部'),
                icon: Icon(Icons.view_list_outlined),
              ),
            ],
            selected: <_OrderViewFilter>{_filter},
            onSelectionChanged: (set) {
              final next = set.isEmpty ? _OrderViewFilter.active : set.first;
              setState(() => _filter = next);
            },
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final ShopOrderListRow order;

  static const Color _green = Color(0xFF2E7D32);

  Future<void> _callElder(BuildContext context) async {
    final raw = order.elderPhone?.trim();
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無長輩電話資料（請確認 profiles.phone 與志工讀取權限）')),
      );
      return;
    }
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話格式無法撥號')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法開啟撥號：$raw')),
      );
    }
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
          content: Text('更新失敗：$e\n若為權限問題，請在 Supabase 執行 orders_volunteer_update_rls.sql'),
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
        const SnackBar(content: Text('已接單，配送時間軸已更新')),
      );
      ref.invalidate(shopVolunteerOrdersProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('接單失敗：$e')));
    }
  }

  Future<void> _milestone(
    BuildContext context,
    WidgetRef ref,
    String eventType,
    String label,
  ) async {
    try {
      await ref.read(shopOrdersRepositoryProvider).addDeliveryMilestone(
            orderId: order.id,
            eventType: eventType,
            note: label,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已記錄：$label')));
      ref.invalidate(shopVolunteerOrdersProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗：$e')));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(shopOrdersRepositoryProvider).completeDelivery(orderId: order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已標記送達')),
      );
      ref.invalidate(shopVolunteerOrdersProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = order.elderDisplayName != null && order.elderDisplayName!.isNotEmpty
        ? order.elderDisplayName!
        : '長輩 ${order.userId.substring(0, 8)}…';

    final statusLine = '${VolunteerShopOrdersPage._formatTime(order.createdAt)} · '
        '狀態：${VolunteerShopOrdersPage._statusLabel(order.status)} · '
        '共 ${order.totalQuantity} 件'
        '${order.totalAmount != null ? ' · 參考總額 ${order.totalAmount} 元' : ''}';

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
                  '聯絡電話：${order.elderPhone}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            const Text(
              '建議先致電長輩，確認品項與數量、是否需要替代品，並表達關心。',
              style: TextStyle(fontSize: 16, height: 1.4),
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
                          content: const Text(
                            '接單後訂單會變為「處理中」，代表您已承諾協助代購。\n\n'
                            '請先確認已與長輩聯繫、品項與數量無誤。\n'
                            '若誤接，可在「處理中」時點「退回待處理」還原。',
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
                    label: const Text('接單（代購）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                if (order.status == 'processing')
                  FilledButton.icon(
                    onPressed: () => _milestone(
                      context,
                      ref,
                      ShopOrderStatus.purchasing,
                      '志工正在門市採買',
                    ),
                    icon: const Icon(Icons.shopping_basket_outlined, size: 22),
                    label: const Text('採買中', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                if (order.status == 'processing')
                  FilledButton.icon(
                    onPressed: () => _milestone(
                      context,
                      ref,
                      ShopOrderStatus.delivering,
                      '物資配送中',
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 22),
                    label: const Text('配送中', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                if (order.status == 'processing')
                  FilledButton.icon(
                    onPressed: () => _complete(context, ref),
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('已送達', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                if (order.status == 'processing')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('退回待處理？'),
                          content: const Text(
                            '訂單將恢復為「待處理」，其他志工也可再次接單。\n'
                            '若已開始採購，請先與里幹部或同仁確認。',
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
                    label: const Text('退回待處理', style: TextStyle(fontSize: 16)),
                  ),
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
              '訂單編號：${order.id}',
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
                    if (item.brand != null && item.brand!.trim().isNotEmpty) item.brand!.trim(),
                    item.productName,
                    if (item.spec != null && item.spec!.trim().isNotEmpty) item.spec!.trim(),
                  ].join(' · '),
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '尚無柑仔店需求單\n長輩送出後會出現在此',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('重新整理', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
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
          '請確認已執行 orders_schema（志工可讀 orders）、orders_volunteer_update_rls.sql（志工可改狀態），並以志工帳號登入。',
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

/// 草稿需求卡片：顯示品項清單 + 「接受需求並轉為正式訂單」按鈕。
class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.isLoading,
    required this.onAccept,
  });

  final DemandRecord draft;
  final bool isLoading;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft.activeItems.isEmpty)
              const Text(
                '（無品項）',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              )
            else
              ...draft.activeItems.map(
                (i) => ShoppingLineTile.fromDemandItem(item: i),
              ),
            const SizedBox(height: 4),
            Text(
              '草稿 · ${VolunteerShopOrdersPage._formatTime(draft.updatedAt)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading || draft.activeItems.isEmpty ? null : onAccept,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  isLoading ? '轉單中...' : '接受需求並轉為正式訂單',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
