import 'package:flutter/material.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';

/// 採買統整單一品項。
final class ProcurementSummaryLine {
  const ProcurementSummaryLine({
    required this.displayName,
    required this.totalQty,
    required this.unitLabel,
    required this.elderCount,
  });

  final String displayName;
  final int totalQty;
  final String unitLabel;
  final int elderCount;
}

/// 將多筆訂單品項合併為採買清單（同品名+品牌+規格+單位加總）。
abstract final class VolunteerProcurementAggregator {
  static List<ProcurementSummaryLine> fromOrders(List<ShopOrderListRow> orders) {
    final map = <String, ({String name, String unit, int qty, Set<String> elders})>{};

    for (final order in orders) {
      final elderKey = order.elderDisplayName ?? order.userId;
      for (final item in order.items) {
        final brand = ElderSupplyTemplates.displayBrandLabel(item.brand);
        final parts = <String>[
          if (brand.trim().isNotEmpty) brand.trim(),
          item.productName,
          if (item.spec != null && item.spec!.trim().isNotEmpty) item.spec!.trim(),
        ];
        final name = parts.join(' ');
        final unit = (item.unitLabel ?? '').trim().isEmpty ? '件' : item.unitLabel!.trim();
        final key = '$name|$unit';
        final existing = map[key];
        if (existing == null) {
          map[key] = (
            name: name,
            unit: unit,
            qty: item.quantity,
            elders: {elderKey},
          );
        } else {
          map[key] = (
            name: existing.name,
            unit: existing.unit,
            qty: existing.qty + item.quantity,
            elders: {...existing.elders, elderKey},
          );
        }
      }
    }

    return map.values
        .map(
          (e) => ProcurementSummaryLine(
            displayName: e.name,
            totalQty: e.qty,
            unitLabel: e.unit,
            elderCount: e.elders.length,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalQty.compareTo(a.totalQty));
  }
}

/// 志工接單前／後的採買統整圖表（橫條圖 + 品項清單）。
abstract final class VolunteerProcurementSummarySheet {
  static Future<bool> showPreviewBeforeAccept(
    BuildContext context, {
    required List<ShopOrderListRow> orders,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProcurementSummaryBody(
        orders: orders,
        title: '接單前採買統整',
        subtitle: '確認後將通知長輩，並於${CommunityProcurementDay.nextProcurementShort()}統一採買',
        confirmLabel: '確認接單（${orders.length} 筆）',
        showConfirm: true,
      ),
    ).then((v) => v == true);
  }

  static Future<void> showAfterAccept(
    BuildContext context, {
    required List<ShopOrderListRow> orders,
    required int acceptedCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProcurementSummaryBody(
        orders: orders,
        title: '已接單 · 採買統整',
        subtitle: '已接 $acceptedCount 筆 · ${CommunityProcurementDay.nextProcurementShort()}採買',
        confirmLabel: '知道了',
        showConfirm: false,
      ),
    );
  }
}

class _ProcurementSummaryBody extends StatelessWidget {
  const _ProcurementSummaryBody({
    required this.orders,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.showConfirm,
  });

  final List<ShopOrderListRow> orders;
  final String title;
  final String subtitle;
  final String confirmLabel;
  final bool showConfirm;

  static const _green = Color(0xFF2E7D32);
  static const _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final lines = VolunteerProcurementAggregator.fromOrders(orders);
    final totalQty = lines.fold<int>(0, (s, l) => s + l.totalQty);
    final maxQty = lines.isEmpty ? 1 : lines.first.totalQty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Material(
          color: const Color(0xFFFFF8E1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          icon: Icons.receipt_long,
                          label: '${orders.length} 筆需求',
                          color: _blue,
                        ),
                        _StatChip(
                          icon: Icons.inventory_2_outlined,
                          label: '$totalQty 件物資',
                          color: _green,
                        ),
                        _StatChip(
                          icon: Icons.category_outlined,
                          label: '${lines.length} 種品項',
                          color: Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: lines.isEmpty
                    ? const Center(
                        child: Text(
                          '尚無品項資料',
                          style: TextStyle(fontSize: 17),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final ratio = line.totalQty / maxQty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        line.displayName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '共 ${line.totalQty} ${line.unitLabel}',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: _green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.08, 1.0),
                                    minHeight: 14,
                                    backgroundColor: Colors.green.shade50,
                                    color: Color.lerp(
                                      Colors.lightGreen.shade300,
                                      _green,
                                      ratio,
                                    ),
                                  ),
                                ),
                                if (line.elderCount > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${line.elderCount} 位長輩需求',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, showConfirm ? true : null),
                  style: FilledButton.styleFrom(
                    backgroundColor: showConfirm ? _green : _blue,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (showConfirm)
                Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 8 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('先不要', style: TextStyle(fontSize: 17)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
