import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';

class ShopElderOrdersPage extends ConsumerWidget {
  const ShopElderOrdersPage({super.key});

  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'pending' => '已送出（待處理）',
      'processing' => '志工處理中',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopElderOrdersProvider);
    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text('我的需求單', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh, size: 28),
              onPressed: () => ref.invalidate(shopElderOrdersProvider),
            ),
          ],
        ),
        body: SafeArea(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _green)),
            error: (e, _) => _ErrorView(
              message: '讀取需求單失敗：$e',
              onRetry: () => ref.invalidate(shopElderOrdersProvider),
            ),
            data: (orders) {
              if (orders.isEmpty) {
                return _EmptyView(onRefresh: () => ref.invalidate(shopElderOrdersProvider));
              }
              return RefreshIndicator(
                color: _green,
                onRefresh: () async {
                  ref.invalidate(shopElderOrdersProvider);
                  await ref.read(shopElderOrdersProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: orders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: Colors.green.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              '這裡會顯示你送出的需求單狀態。\n若需要更改或取消，請先聯絡志工或里幹部協助。',
                              style: TextStyle(fontSize: 16, height: 1.4),
                            ),
                          ),
                        ),
                      );
                    }
                    final o = orders[index - 1];
                    return _OrderCard(order: o, displayNo: index);
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.displayNo});

  final ShopOrderListRow order;
  /// 畫面上顯示的簡易序號（1、2、3…），方便長輩口述；完整 UUID 見下方。
  final int displayNo;

  @override
  Widget build(BuildContext context) {
    final statusLine = '${ShopElderOrdersPage._formatTime(order.createdAt)} · '
        '${ShopElderOrdersPage._statusLabel(order.status)} · '
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
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          title: Text(
            '需求單 $displayNo',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(statusLine, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ),
          children: [
            for (final it in order.items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(it.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  it.unitPrice != null
                      ? '× ${it.quantity}（參考單價 ${it.unitPrice!.toStringAsFixed(0)} 元）'
                      : '× ${it.quantity}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                ),
              ),
            const SizedBox(height: 4),
            SelectableText(
              '系統編號（報給志工核對）：${order.id}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => context.push('/shop/orders/${order.id}'),
              icon: const Icon(Icons.timeline),
              label: const Text('查看配送進度', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: ShopElderOrdersPage._green,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
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
            '尚無需求單\n你從柑仔店送出後會出現在此',
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
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
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.45)),
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

