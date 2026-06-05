import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/domain/daily_shopping_line.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_item_fulfillment_sheet.dart';

/// 志工：今日全聯採買清單（聚合品項 + 長輩明細）。
class VolunteerDailyShoppingListPanel extends ConsumerStatefulWidget {
  const VolunteerDailyShoppingListPanel({super.key});

  @override
  ConsumerState<VolunteerDailyShoppingListPanel> createState() =>
      _VolunteerDailyShoppingListPanelState();
}

class _VolunteerDailyShoppingListPanelState
    extends ConsumerState<VolunteerDailyShoppingListPanel> {
  String? _locationPointId;
  bool _loadingLoc = true;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final userId = ref.read(authProvider)?.user.id;
    if (userId == null) {
      setState(() => _loadingLoc = false);
      return;
    }
    final loc = await const DemandRecordsRepository()
        .fetchElderLocationPointId(userId);
    if (mounted) {
      setState(() {
        _locationPointId = loc;
        _loadingLoc = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLoc) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final locId = _locationPointId;
    if (locId == null || locId.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('請先設定據點以顯示今日採買清單', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final listAsync = ref.watch(
      dailyShoppingListProvider((locationPointId: locId, date: DateTime.now())),
    );

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart_checkout,
                    color: Colors.green.shade800, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '今日採買清單',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(
                    dailyShoppingListProvider(
                      (locationPointId: locId, date: DateTime.now()),
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              '同據點 pending／已接單品項，依品類→品牌→規格聚合。',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            listAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('載入失敗：$e'),
              data: (lines) {
                if (lines.isEmpty) {
                  return const Text('今日尚無待採買品項', style: TextStyle(fontSize: 16));
                }
                return Column(
                  children: [
                    for (final line in lines)
                      _LineTile(line: line, locationPointId: locId),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF1F8E9),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: Text(
          '${line.displayTitle} — 共 ${line.totalQty} ${line.unitLabel}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        children: [
          for (final e in line.elderLines)
            ListTile(
              dense: true,
              title: Text('${e.elderDisplay} × ${e.quantity}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: '更新狀態',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => VolunteerItemFulfillmentSheet(
                    itemId: e.itemId,
                    productLabel: line.displayTitle,
                    elderLabel: e.elderDisplay,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.tonal(
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
              child: const Text('一鍵接單（全部長輩）'),
            ),
          ),
        ],
      ),
    );
  }
}
