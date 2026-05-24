import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
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
        return _OrderDetailBody(order: order);
      },
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});

  final ShopOrderListRow order;

  @override
  Widget build(BuildContext context) {
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
                    title: Text(it.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '× ${it.quantity}'
                      '${it.unitPrice != null ? ' · ${it.unitPrice!.toStringAsFixed(0)} 元' : ''}',
                      style: const TextStyle(fontSize: 16),
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
