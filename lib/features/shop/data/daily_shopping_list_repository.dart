import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/daily_shopping_line.dart';

class DailyShoppingListRepository {
  DailyShoppingListRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<DailyShoppingLine>> fetch({
    required String locationPointId,
    DateTime? shoppingDate,
  }) async {
    final date = shoppingDate ?? DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final raw = await _client.rpc(
        'get_daily_shopping_list',
        params: {
          'p_location_point_id': locationPointId,
          'p_shopping_date': dateStr,
        },
      );
      final lines = parseDailyShoppingRpcPayload(raw);
      if (lines.isNotEmpty) return lines;
    } catch (_) {
      // fallback below
    }
    return _aggregateFromItems(locationPointId);
  }

  Future<List<DailyShoppingLine>> _aggregateFromItems(
    String locationPointId,
  ) async {
    try {
      final records = await _client
          .from('demand_records')
          .select(
            'id, user_id, demand_record_items(id, product_name, quantity, '
            'unit_label, category, brand, spec, fulfillment_status, cancelled, '
            'category_id, brand_id, product_item_id, profiles(name))',
          )
          .eq('location_point_id', locationPointId)
          .inFilter('status', ['submitted', 'pending', 'processing']);

      final inputs = <_AggInput>[];
      for (final rec in List<Map>.from(records as List? ?? const [])) {
        final recordId = rec['id']?.toString() ?? '';
        final elderId = rec['user_id']?.toString() ?? '';
        final items = rec['demand_record_items'];
        if (items is! List) continue;
        for (final it in items) {
          if (it is! Map) continue;
          if (it['cancelled'] == true) continue;
          final fs = it['fulfillment_status']?.toString() ?? 'pending';
          if (fs != 'pending' && fs != 'accepted') continue;
          inputs.add(
            _AggInput(
              itemId: it['id']?.toString() ?? '',
              demandRecordId: recordId,
              elderUserId: elderId,
              elderDisplay: it['product_name']?.toString() ?? elderId,
              categoryLabel: it['category']?.toString() ?? '未分類',
              brandLabel: it['brand']?.toString(),
              specLabel: it['spec']?.toString(),
              unitLabel: it['unit_label']?.toString() ?? '包',
              productItemId: it['product_item_id']?.toString(),
              quantity: (it['quantity'] as num?)?.toInt() ?? 1,
            ),
          );
        }
      }

      final groups = <String, List<_AggInput>>{};
      for (final i in inputs) {
        final key = i.productItemId ??
            '${i.categoryLabel}|${i.brandLabel ?? ""}|${i.specLabel ?? ""}';
        groups.putIfAbsent(key, () => []).add(i);
      }

      return [
        for (final entry in groups.entries)
          DailyShoppingLine(
            groupKey: entry.key,
            productItemId: entry.value.first.productItemId,
            categoryLabel: entry.value.first.categoryLabel,
            brandLabel: entry.value.first.brandLabel,
            specLabel: entry.value.first.specLabel,
            unitLabel: entry.value.first.unitLabel,
            totalQty: entry.value.fold(0, (s, e) => s + e.quantity),
            elderLines: [
              for (final e in entry.value)
                DailyShoppingElderLine(
                  itemId: e.itemId,
                  elderUserId: e.elderUserId,
                  elderDisplay: e.elderDisplay,
                  quantity: e.quantity,
                  demandRecordId: e.demandRecordId,
                ),
            ],
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// RPC 回傳單一 jsonb 陣列（非 setof），Supabase client 可能為 List 或 JSON 字串。
List<DailyShoppingLine> parseDailyShoppingRpcPayload(dynamic raw) {
  if (raw == null) return const [];
  dynamic decoded = raw;
  if (raw is String) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map(
        (e) => DailyShoppingLine.fromJson(
          Map<String, dynamic>.from(e),
        ),
      )
      .toList();
}

class _AggInput {
  _AggInput({
    required this.itemId,
    required this.demandRecordId,
    required this.elderUserId,
    required this.elderDisplay,
    required this.categoryLabel,
    this.brandLabel,
    this.specLabel,
    required this.unitLabel,
    this.productItemId,
    required this.quantity,
  });

  final String itemId;
  final String demandRecordId;
  final String elderUserId;
  final String elderDisplay;
  final String categoryLabel;
  final String? brandLabel;
  final String? specLabel;
  final String unitLabel;
  final String? productItemId;
  final int quantity;
}
