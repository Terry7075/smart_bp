import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/shop/domain/fulfillment_status.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/order_delivery_timeline.dart';

/// 訂單詳情（配送時間軸 + 品項明細，Supabase Realtime 更新）。
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
          title: const Text('訂單詳情', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
        body: Center(child: Text('讀取失敗：$e', style: const TextStyle(fontSize: 18))),
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
    final fulfillmentAsync = ref.watch(orderItemFulfillmentProvider(orderId));
    return Scaffold(
      backgroundColor: ShopOrderDetailPage._cream,
      appBar: AppBar(
        backgroundColor: ShopOrderDetailPage._green,
        foregroundColor: Colors.white,
        title: const Text('訂單詳情', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    ShopOrderStatus.orderStatusLabel(order.status),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ShopOrderDetailPage._green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '共 ${order.totalQuantity} 件'
                    '${order.totalAmount != null ? ' · 參考 ${order.totalAmount} 元' : ''}',
                    style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
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
          fulfillmentAsync.when(
            data: (rows) {
              if (rows.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '品項採買進度由志工更新；訂單狀態與品項狀態可能不同步，以志工通知為準。',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
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
