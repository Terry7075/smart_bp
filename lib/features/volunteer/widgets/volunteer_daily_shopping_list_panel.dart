import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';
import 'package:smart_bp/features/shop/data/location_points_repository.dart';
import 'package:smart_bp/features/shop/domain/daily_shopping_line.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_item_fulfillment_sheet.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_procurement_summary_sheet.dart';

/// 社區代購統一配送地點（志工採買後送達處）。
const volunteerDeliveryHubLabel = '活動中心';

const _kGreen = Color(0xFF2E7D32);
const _kGreenLight = Color(0xFFE8F5E9);
const _kGreenPale = Color(0xFFF1F8E9);

/// 志工端可見的配送據點（僅已送出的正式需求單）。
final volunteerShoppingLocationsProvider =
    FutureProvider<List<LocationPoint>>((ref) async {
  final points = await const LocationPointsRepository().listPoints();
  final byId = <String, LocationPoint>{for (final p in points) p.id: p};

  List<ShopOrderListRow> orders = const [];
  try {
    orders = await ref.watch(shopVolunteerOrdersProvider.future);
  } catch (_) {}

  void add(String? id, String? name) {
    if (id == null || id.isEmpty) return;
    byId.putIfAbsent(
      id,
      () => LocationPoint(
        id: id,
        name: (name ?? '').trim().isEmpty
            ? volunteerDeliveryHubLabel
            : name!.trim(),
      ),
    );
  }

  for (final o in orders) {
    add(o.locationPointId, o.locationPointName);
  }

  final list = byId.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return list;
});

/// 志工：下次採購日代購總清單（彙整品項 + 長輩明細）。
class VolunteerDailyShoppingListPanel extends ConsumerWidget {
  const VolunteerDailyShoppingListPanel({super.key});

  static bool _isActiveOrder(ShopOrderListRow o) =>
      o.status == 'pending' || o.status == 'processing';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(shopVolunteerOrdersProvider);
    final locationsAsync = ref.watch(volunteerShoppingLocationsProvider);

    return Card(
      elevation: 2,
      shadowColor: _kGreen.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListHeader(
            onRefresh: () {
              ref.invalidate(volunteerShoppingLocationsProvider);
              ref.invalidate(shopVolunteerOrdersProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ordersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: _kGreen)),
              ),
              error: (e, _) => _EmptyHint(
                icon: Icons.error_outline,
                message: '載入失敗：$e',
              ),
              data: (orders) => locationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: _kGreen)),
                ),
                error: (e, _) => _EmptyHint(
                  icon: Icons.error_outline,
                  message: '載入失敗：$e',
                ),
                data: (locations) {
                  final activeOrders =
                      orders.where(_isActiveOrder).toList();
                  final aggregated =
                      VolunteerProcurementAggregator.fromOrders(activeOrders);
                  final fallback = _aggregateUnassigned(activeOrders);
                  final hasLocated = locations.isNotEmpty;
                  final hasFallback = fallback.isNotEmpty;

                  if (!hasLocated && !hasFallback) {
                    return const _EmptyHint(
                      icon: Icons.shopping_basket_outlined,
                      message: '尚無待採買品項',
                    );
                  }

                  final totalQty =
                      aggregated.fold<int>(0, (s, l) => s + l.totalQty);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (aggregated.isNotEmpty) ...[
                        _SummaryStrip(
                          itemKinds: aggregated.length,
                          totalQty: totalQty,
                          locationCount: locations.length,
                        ),
                        const SizedBox(height: 14),
                        _TopItemsChart(lines: aggregated.take(6).toList()),
                        const SizedBox(height: 16),
                      ],
                      for (final loc in locations) ...[
                        _LocationSection(
                          location: loc,
                          date: DateTime.now(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (hasFallback) _UnassignedSection(lines: fallback),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreen, _kGreen.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CommunityProcurementDay.volunteerAggregateListTitle(),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '重新整理',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.itemKinds,
    required this.totalQty,
    required this.locationCount,
  });

  final int itemKinds;
  final int totalQty;
  final int locationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              value: '$itemKinds',
              label: '種品項',
              icon: Icons.category_outlined,
            ),
          ),
          Container(width: 1, height: 36, color: _kGreen.withValues(alpha: 0.2)),
          Expanded(
            child: _MiniStat(
              value: '$totalQty',
              label: '件物資',
              icon: Icons.inventory_2_outlined,
            ),
          ),
          Container(width: 1, height: 36, color: _kGreen.withValues(alpha: 0.2)),
          Expanded(
            child: _MiniStat(
              value: '$locationCount',
              label: '據點',
              icon: Icons.place_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: _kGreen),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _kGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _TopItemsChart extends StatelessWidget {
  const _TopItemsChart({required this.lines});

  final List<ProcurementSummaryLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final maxQty = lines.first.totalQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '採買量 TOP',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _kGreen,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BarRow(
              rank: i + 1,
              name: lines[i].displayName,
              qty: lines[i].totalQty,
              unit: lines[i].unitLabel,
              ratio: lines[i].totalQty / maxQty,
              elderCount: lines[i].elderCount,
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.unit,
    required this.ratio,
    required this.elderCount,
  });

  final int rank;
  final String name;
  final int qty;
  final String unit;
  final double ratio;
  final int elderCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank <= 3
                ? _kGreen.withValues(alpha: 0.15)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? _kGreen : Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$qty $unit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.06, 1.0),
                  minHeight: 8,
                  backgroundColor: _kGreenPale,
                  color: Color.lerp(
                    Colors.lightGreen.shade300,
                    _kGreen,
                    ratio,
                  ),
                ),
              ),
              if (elderCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '$elderCount 位長輩',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends ConsumerWidget {
  const _LocationSection({required this.location, required this.date});

  final LocationPoint location;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(
      dailyShoppingListProvider(
        (locationPointId: location.id, date: date),
      ),
    );

    return listAsync.when(
      loading: () => _LocationBanner(
        name: location.name,
        itemCount: null,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(color: _kGreen),
        ),
      ),
      error: (e, _) => _LocationBanner(
        name: location.name,
        itemCount: null,
        child: Text('載入失敗：$e', style: const TextStyle(fontSize: 15)),
      ),
      data: (lines) {
        if (lines.isEmpty) return const SizedBox.shrink();
        return _LocationBanner(
          name: location.name,
          itemCount: lines.length,
          child: Column(
            children: [
              for (final line in lines)
                _LineTile(line: line, locationPointId: location.id),
            ],
          ),
        );
      },
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.name,
    required this.itemCount,
    required this.child,
  });

  final String name;
  final int? itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kGreenPale,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: _kGreen, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _kGreen,
                    ),
                  ),
                ),
                if (itemCount != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$itemCount 項',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SimpleProcurementLine {
  _SimpleProcurementLine({
    required this.title,
    required this.unitLabel,
  });

  final String title;
  final String unitLabel;
  final List<({String elder, int qty})> details = [];
}

List<_SimpleProcurementLine> _aggregateUnassigned(
  List<ShopOrderListRow> orders,
) {
  final map = <String, _SimpleProcurementLine>{};

  void add({
    required String? locationId,
    required String key,
    required String title,
    required String elder,
    required int qty,
    required String unit,
  }) {
    if (locationId != null && locationId.isNotEmpty) return;
    final line = map.putIfAbsent(
      key,
      () => _SimpleProcurementLine(title: title, unitLabel: unit),
    );
    line.details.add((elder: elder, qty: qty));
  }

  String itemKey(ShopOrderItemRow item) =>
      '${item.category ?? ""}|${item.brand ?? ""}|${item.spec ?? ""}|${item.productName}';

  String itemTitle(ShopOrderItemRow item) {
    final parts = [
      if (item.category != null && item.category!.isNotEmpty) item.category,
      if (item.brand != null && item.brand!.isNotEmpty) item.brand,
      if (item.spec != null && item.spec!.isNotEmpty) item.spec,
      item.productName,
    ];
    return parts.join('｜');
  }

  for (final o in orders) {
    final elder = (o.elderDisplayName ?? '').trim().isEmpty
        ? '長輩'
        : o.elderDisplayName!.trim();
    for (final item in o.items) {
      add(
        locationId: o.locationPointId,
        key: itemKey(item),
        title: itemTitle(item),
        elder: elder,
        qty: item.quantity,
        unit: item.unitLabel ?? '件',
      );
    }
  }

  return map.values.toList()
    ..sort((a, b) {
      final aQty = a.details.fold(0, (s, e) => s + e.qty);
      final bQty = b.details.fold(0, (s, e) => s + e.qty);
      return bQty.compareTo(aQty);
    });
}

class _UnassignedSection extends StatelessWidget {
  const _UnassignedSection({required this.lines});

  final List<_SimpleProcurementLine> lines;

  @override
  Widget build(BuildContext context) {
    return _LocationBanner(
      name: volunteerDeliveryHubLabel,
      itemCount: lines.length,
      child: Column(
        children: [
          for (final line in lines)
            _SimpleLineCard(line: line),
        ],
      ),
    );
  }
}

class _SimpleLineCard extends StatelessWidget {
  const _SimpleLineCard({required this.line});

  final _SimpleProcurementLine line;

  @override
  Widget build(BuildContext context) {
    final total = line.details.fold<int>(0, (s, e) => s + e.qty);

    return _ProcurementItemShell(
      title: line.title,
      totalQty: total,
      unitLabel: line.unitLabel,
      elderCount: line.details.length,
      children: [
        for (final d in line.details)
          _ElderRow(label: d.elder, qty: d.qty),
      ],
    );
  }
}

class _LineTile extends ConsumerStatefulWidget {
  const _LineTile({required this.line, required this.locationPointId});
  final DailyShoppingLine line;
  final String locationPointId;

  @override
  ConsumerState<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends ConsumerState<_LineTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final locId = widget.locationPointId;

    return _ProcurementItemShell(
      title: line.displayTitle,
      totalQty: line.totalQty,
      unitLabel: line.unitLabel,
      elderCount: line.elderLines.length,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      children: [
        for (final e in line.elderLines)
          _ElderRow(
            label: e.elderDisplay,
            qty: e.quantity,
            onEdit: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => VolunteerItemFulfillmentSheet(
                itemId: e.itemId,
                productLabel: line.displayTitle,
                elderLabel: e.elderDisplay,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: OutlinedButton.icon(
            onPressed: () async {
              final repo = ref.read(fulfillmentRepositoryProvider);
              await repo.acceptItems(
                line.elderLines.map((e) => e.itemId).toList(),
              );
              ref.invalidate(
                dailyShoppingListProvider(
                  (locationPointId: locId, date: DateTime.now()),
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已接單此品項所有明細')),
                );
              }
            },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('此品項全部接單'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreen,
              side: BorderSide(color: _kGreen.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcurementItemShell extends StatelessWidget {
  const _ProcurementItemShell({
    required this.title,
    required this.totalQty,
    required this.unitLabel,
    required this.elderCount,
    required this.children,
    this.expanded = false,
    this.onToggle,
  });

  final String title;
  final int totalQty;
  final String unitLabel;
  final int elderCount;
  final List<Widget> children;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _kGreenPale,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _kGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '$totalQty',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$elderCount 位長輩 · $unitLabel',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onToggle != null)
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: _kGreen,
                      ),
                  ],
                ),
              ),
              if (expanded) ...[
                Divider(height: 1, color: _kGreen.withValues(alpha: 0.12)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Column(children: children),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderRow extends StatelessWidget {
  const _ElderRow({
    required this.label,
    required this.qty,
    this.onEdit,
  });

  final String label;
  final int qty;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _kGreen.withValues(alpha: 0.12),
            child: Text(
              label.isNotEmpty ? label.characters.first : '長',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '× $qty',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _kGreen,
              ),
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_note, size: 22),
              tooltip: '更新狀態',
              color: _kGreen,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
