import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_volunteer_orders_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 志工端：全聯／柑仔店參考需求單列表（Supabase）。
class VolunteerShopOrdersPage extends ConsumerStatefulWidget {
  const VolunteerShopOrdersPage({super.key});

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

  static bool _isActive(ShopOrderListRow o) => o.status == 'pending' || o.status == 'processing';
  static bool _isHistory(ShopOrderListRow o) => o.status == 'completed' || o.status == 'cancelled';

  List<ShopOrderListRow> _applyFilter(List<ShopOrderListRow> orders) {
    return switch (_filter) {
      _OrderViewFilter.active => orders.where(_isActive).toList(),
      _OrderViewFilter.history => orders.where(_isHistory).toList(),
      _OrderViewFilter.all => orders,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopVolunteerOrdersProvider);

    return RoleGuard(
      requiredRole: RoleGuardTarget.volunteer,
      child: Scaffold(
        backgroundColor: VolunteerShopOrdersPage._backgroundCream,
        appBar: AppBar(
          backgroundColor: VolunteerShopOrdersPage._volunteerBlue,
          foregroundColor: Colors.white,
          title: const Text(
            '物資／柑仔店需求',
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
        body: SafeArea(
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
              if (filtered.isEmpty) {
                return _EmptyBody(
                  onRefresh: () => ref.invalidate(shopVolunteerOrdersProvider),
                );
              }
              return RefreshIndicator(
                color: VolunteerShopOrdersPage._volunteerBlue,
                onRefresh: () async {
                  ref.invalidate(shopVolunteerOrdersProvider);
                  await ref.read(shopVolunteerOrdersProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
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
                    final o = filtered[index - 1];
                    return _OrderCard(order: o);
                  },
                ),
              );
            },
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
                        await _setStatus(context, ref, 'processing');
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
                    onPressed: () => _setStatus(context, ref, 'completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text('標記完成', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  it.productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  it.unitPrice != null
                      ? '× ${it.quantity}（參考單價 ${it.unitPrice!.toStringAsFixed(0)} 元）'
                      : '× ${it.quantity}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                ),
              ),
            const SizedBox(height: 4),
            SelectableText(
              '訂單編號：${order.id}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
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
