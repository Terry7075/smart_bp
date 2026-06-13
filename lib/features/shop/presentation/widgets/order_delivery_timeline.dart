import 'package:flutter/material.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';

/// 訂單配送垂直時間軸（長輩／家屬／志工共用）。
class OrderDeliveryTimeline extends StatelessWidget {
  const OrderDeliveryTimeline({
    super.key,
    required this.order,
    this.compact = false,
  });

  final ShopOrderListRow order;
  final bool compact;

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.month}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  static IconData _iconFor(String type) {
    return switch (type) {
      ShopOrderStatus.created => Icons.send_outlined,
      ShopOrderStatus.accepted => Icons.volunteer_activism_outlined,
      ShopOrderStatus.purchasing => Icons.shopping_basket_outlined,
      ShopOrderStatus.delivering => Icons.local_shipping_outlined,
      ShopOrderStatus.delivered => Icons.home_outlined,
      ShopOrderStatus.issue => Icons.warning_amber_outlined,
      _ => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final events = order.timelineEvents;
    final accent = order.deliveryIssue != null
        ? const Color(0xFFE65100)
        : const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.deliveryIssue != null && order.deliveryIssue!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: const Color(0xFFFFF3E0),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '配送備註：${order.deliveryIssue}',
                        style: const TextStyle(fontSize: 16, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...List.generate(events.length, (i) {
          final e = events[i];
          final isLast = i == events.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 36 : 44,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: compact ? 16 : 20,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Icon(_iconFor(e.eventType), color: accent, size: compact ? 18 : 22),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16, left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ShopOrderStatus.eventTypeLabel(e.eventType),
                          style: TextStyle(
                            fontSize: compact ? 17 : 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          _formatTime(e.createdAt),
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                        ),
                        if (e.note != null && e.note!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              e.note!,
                              style: TextStyle(fontSize: compact ? 15 : 16, height: 1.35, color: Colors.grey.shade800),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
