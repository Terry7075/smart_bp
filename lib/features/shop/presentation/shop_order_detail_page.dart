import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/shop/domain/fulfillment_status.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/order_delivery_timeline.dart';

/// 需求單詳情（配送時間軸 + 品項明細，Supabase Realtime 更新）。
class ShopOrderDetailPage extends ConsumerWidget {
  const ShopOrderDetailPage({
    super.key,
    required this.orderId,
    this.readOnly = false,
  });

  final String orderId;
  final bool readOnly;

  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopOrderDetailStreamProvider(orderId));

    return async.when(
      loading: () => Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text('需求單詳情', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator(color: _green)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: const Center(
          child: Text('讀取失敗，請稍後再試。', style: TextStyle(fontSize: 18)),
        ),
      ),
      data: (order) {
        if (order == null) {
          return Scaffold(
            backgroundColor: _cream,
            appBar: AppBar(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
            ),
            body: const Center(child: Text('找不到此訂單', style: TextStyle(fontSize: 20))),
          );
        }
        return _OrderDetailBody(order: order, orderId: orderId);
      },
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order, required this.orderId});

  final ShopOrderListRow order;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(shopOrderDetailStreamProvider(orderId), (prev, next) {
      final prevStatus = prev?.value?.status;
      final nextStatus = next.value?.status;
      if (nextStatus != null && prevStatus != nextStatus) {
        ref.invalidate(orderItemFulfillmentProvider(orderId));
      }
    });
    final fulfillmentAsync = ref.watch(orderItemFulfillmentProvider(orderId));
    return Scaffold(
      backgroundColor: ShopOrderDetailPage._cream,
      appBar: AppBar(
        backgroundColor: ShopOrderDetailPage._green,
        foregroundColor: Colors.white,
        title: const Text('需求單詳情', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.sync, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    '即時',
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.95)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '共 ${order.totalQuantity} 件'
                    '${order.totalAmount != null ? ' · 參考 ${order.totalAmount} 元' : ''}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ShopOrderDetailPage._green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '送出時間：${_formatOrderTime(order.createdAt)}',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          // 緊急提示 banner
          if (order.isUrgent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE65100), width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.emergency, color: Color(0xFFE65100), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '您已標記此單為緊急需求，志工端將優先處理。',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBF360C),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('配送進度', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OrderDeliveryTimeline(order: order),
            ),
          ),
          const SizedBox(height: 16),
          const Text('品項明細', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final it in order.items)
                  ListTile(
                    title: Text(it.productName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      () {
                        final unitPart = it.unitLabel != null && it.unitLabel!.isNotEmpty
                            ? ' ${it.unitLabel}'
                            : '';
                        final pricePart = it.unitPrice != null
                            ? '・${it.unitPrice!.toStringAsFixed(0)} 元'
                            : '';
                        return '× ${it.quantity}$unitPart$pricePart';
                      }(),
                      style: const TextStyle(fontSize: 17),
                    ),
                    trailing: fulfillmentAsync.when(
                      data: (rows) {
                        final match = rows.where(
                          (r) =>
                              r.productName == it.productName ||
                              (it.brand != null && r.brand == it.brand),
                        );
                        final status = match.isNotEmpty
                            ? match.first.fulfillmentStatus
                            : null;
                        if (status == null) return null;
                        return Chip(
                          label: Text(
                            status.label,
                            style: const TextStyle(fontSize: 14),
                          ),
                          backgroundColor: _fulfillmentColor(status),
                        );
                      },
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OrderStatusSummaryCard(order: order),
        ],
      ),
    );
  }

  static String _formatOrderTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  static Color _fulfillmentColor(ItemFulfillmentStatus status) {
    return switch (status) {
      ItemFulfillmentStatus.pending => Colors.orange.shade100,
      ItemFulfillmentStatus.accepted => Colors.blue.shade100,
      ItemFulfillmentStatus.purchased => Colors.green.shade100,
      ItemFulfillmentStatus.delivered => Colors.green.shade200,
      ItemFulfillmentStatus.substituted => Colors.amber.shade100,
      ItemFulfillmentStatus.cancelled => Colors.grey.shade300,
    };
  }
}

class _OrderStatusSummaryCard extends StatelessWidget {
  const _OrderStatusSummaryCard({required this.order});

  final ShopOrderListRow order;

  @override
  Widget build(BuildContext context) {
    final statusLabel = ShopOrderStatus.elderOrderStatusLabel(
      order.status,
      hasProcuring: order.hasProcuringMilestone,
    );
    final accent = _statusAccent(order.status, order.hasProcuringMilestone);

    return Card(
      color: accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_statusIcon(order.status), color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目前狀態',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${order.totalQuantity} 件'
                    '${order.totalAmount != null ? ' · 參考 ${order.totalAmount} 元' : ''}',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusAccent(String status, bool hasProcuring) {
    if (status == 'processing' && hasProcuring) {
      return const Color(0xFF1565C0);
    }
    return switch (status) {
      'pending' => const Color(0xFFE65100),
      'processing' => const Color(0xFF1565C0),
      'completed' => const Color(0xFF2E7D32),
      'cancelled' => Colors.grey.shade700,
      _ => const Color(0xFF5D4037),
    };
  }

  static IconData _statusIcon(String status) {
    return switch (status) {
      'pending' => Icons.hourglass_top_rounded,
      'processing' => Icons.local_shipping_outlined,
      'completed' => Icons.check_circle_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };
  }
}
