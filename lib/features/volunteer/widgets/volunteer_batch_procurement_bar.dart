import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_shop_confirm_dialog.dart';

/// 志工端：今日採買清單上方的統一批次操作（採買中／全部送達）。
class VolunteerBatchProcurementBar extends ConsumerStatefulWidget {
  const VolunteerBatchProcurementBar({super.key});

  @override
  ConsumerState<VolunteerBatchProcurementBar> createState() =>
      _VolunteerBatchProcurementBarState();
}

class _VolunteerBatchProcurementBarState
    extends ConsumerState<VolunteerBatchProcurementBar> {
  bool _busy = false;

  static List<ShopOrderListRow> _processing(List<ShopOrderListRow> orders) =>
      orders.where((o) => o.status == 'processing').toList();

  static int _needsProcuringCount(List<ShopOrderListRow> processing) =>
      processing.where((o) => !o.hasProcuringMilestone).length;

  Future<void> _batchProcuring(List<ShopOrderListRow> processing) async {
    final count = _needsProcuringCount(processing);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有處理中需求單皆已標記採買中')),
      );
      return;
    }
    final ok = await VolunteerShopConfirmDialog.confirmBatchProcuring(
      context,
      orderCount: count,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(shopOrdersRepositoryProvider)
          .batchMarkProcuring(processing);
      ref.invalidate(shopVolunteerOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1565C0),
          content: Text(
            '已標記 $updated 筆為「採買中」，長輩端時間軸已更新',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批次更新失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _batchComplete(List<ShopOrderListRow> processing) async {
    if (processing.isEmpty) return;
    final ok = await VolunteerShopConfirmDialog.confirmBatchCompleteDelivery(
      context,
      orders: processing,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(shopOrdersRepositoryProvider)
          .batchCompleteDeliveries(processing);
      ref.invalidate(shopVolunteerOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(
            '已標記 $updated 筆「已送達活動中心」',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批次送達失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(shopVolunteerOrdersProvider);

    return ordersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (orders) {
        final processing = _processing(orders);
        if (processing.isEmpty) return const SizedBox.shrink();

        final procuringPending = _needsProcuringCount(processing);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '批次進度',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy || procuringPending == 0
                              ? null
                              : () => _batchProcuring(processing),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.shopping_cart_checkout),
                          label: Text(
                            procuringPending > 0
                                ? '標記採買中（$procuringPending）'
                                : '已採買中',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _batchComplete(processing),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            '全部送達（${processing.length} 筆）',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
