import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/purchase_batch_aggregator.dart';
import 'package:smart_bp/features/shop/data/purchase_route_planner.dart';

final class VolunteerPurchaseBatchLine {
  const VolunteerPurchaseBatchLine({
    required this.id,
    required this.categoryLabel,
    this.brandLabel,
    required this.aggregatedQuantity,
    this.unitLabel,
    this.completed = false,
  });

  final String id;
  final String categoryLabel;
  final String? brandLabel;
  final int aggregatedQuantity;
  final String? unitLabel;
  final bool completed;
}

final class VolunteerPurchaseBatch {
  const VolunteerPurchaseBatch({
    required this.id,
    required this.locationPointId,
    required this.status,
    required this.lines,
    this.plannedRouteJson,
    this.totalEstimatedCost,
  });

  final String id;
  final String locationPointId;
  final String status;
  final List<VolunteerPurchaseBatchLine> lines;
  final Map<String, dynamic>? plannedRouteJson;
  final double? totalEstimatedCost;
}

/// 批次採買 CRUD + 聚合 + 路線。
class PurchaseBatchRepository {
  const PurchaseBatchRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchPendingItems({
    required String locationPointId,
  }) async {
    final raw = await _client
        .from('demand_records')
        .select(
          'id, user_id, location_point_id, status, '
          'demand_record_items(id, product_name, quantity, unit_label, category, '
          'supply_category_key, brand, category_id, brand_id, batch_line_id, cancelled)',
        )
        .eq('location_point_id', locationPointId)
        .inFilter('status', ['submitted', 'draft']);

    final out = <Map<String, dynamic>>[];
    for (final row in List<dynamic>.from(raw as List? ?? const [])) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final items = m['demand_record_items'];
      if (items is! List) continue;
      for (final it in items) {
        if (it is! Map) continue;
        final im = Map<String, dynamic>.from(it);
        if (im['cancelled'] == true) continue;
        if (im['batch_line_id'] != null) continue;
        out.add({
          'location_point_id': m['location_point_id'],
          'demand_record_id': m['id'],
          'elder_user_id': m['user_id'],
          'item_id': im['id'],
          'product_name': im['product_name'],
          'quantity': im['quantity'],
          'unit_label': im['unit_label'],
          'category': im['category'],
          'supply_category_key': im['supply_category_key'],
          'brand': im['brand'],
          'category_id': im['category_id'],
          'brand_id': im['brand_id'],
        });
      }
    }
    return out;
  }

  Future<VolunteerPurchaseBatch> createBatchFromLocation({
    required String volunteerId,
    required String locationPointId,
  }) async {
    final pending = await fetchPendingItems(locationPointId: locationPointId);
    final aggregateInput = [
      for (final p in pending)
        BatchItemInput(
          itemId: p['item_id']?.toString() ?? '',
          demandRecordId: p['demand_record_id']?.toString() ?? '',
          elderUserId: p['elder_user_id']?.toString() ?? '',
          categoryKey: p['supply_category_key']?.toString() ??
              p['category']?.toString() ??
              'other',
          categoryLabel: p['category']?.toString() ?? '其他',
          brandLabel: p['brand']?.toString(),
          categoryId: p['category_id']?.toString(),
          brandId: p['brand_id']?.toString(),
          quantity: (p['quantity'] as num?)?.toInt() ?? 1,
          unitLabel: p['unit_label']?.toString(),
        ),
    ];

    final lines = PurchaseBatchAggregator.aggregate(aggregateInput);

    final batchRow = await _client
        .from('volunteer_purchase_batches')
        .insert({
          'location_point_id': locationPointId,
          'volunteer_id': volunteerId,
          'status': 'collecting',
        })
        .select('id, location_point_id, status, planned_route_json, total_estimated_cost')
        .single();

    final batchId = batchRow['id']?.toString() ?? '';
    final insertedLines = <VolunteerPurchaseBatchLine>[];

    for (final line in lines) {
      final lineRow = await _client
          .from('volunteer_purchase_batch_lines')
          .insert({
            'batch_id': batchId,
            'category_id': line.categoryId,
            'brand_id': line.brandId,
            'category_label': line.categoryLabel,
            'brand_label': line.brandLabel,
            'aggregated_quantity': line.aggregatedQuantity,
            'unit_label': line.unitLabel,
            'source_item_ids': line.sourceItemIds,
          })
          .select('id, category_label, brand_label, aggregated_quantity, unit_label, completed')
          .single();

      final lineId = lineRow['id']?.toString() ?? '';
      for (final itemId in line.sourceItemIds) {
        await _client
            .from('demand_record_items')
            .update({'batch_line_id': lineId})
            .eq('id', itemId);
      }

      for (final drId in line.demandRecordIds) {
        try {
          await _client.from('volunteer_purchase_batch_members').insert({
            'batch_id': batchId,
            'demand_record_id': drId,
            'elder_user_id': line.elderUserIds[drId] ?? volunteerId,
          });
        } catch (_) {}
      }

      insertedLines.add(
        VolunteerPurchaseBatchLine(
          id: lineId,
          categoryLabel: lineRow['category_label']?.toString() ?? '',
          brandLabel: lineRow['brand_label']?.toString(),
          aggregatedQuantity: (lineRow['aggregated_quantity'] as num?)?.toInt() ?? 0,
          unitLabel: lineRow['unit_label']?.toString(),
        ),
      );
    }

    return VolunteerPurchaseBatch(
      id: batchId,
      locationPointId: locationPointId,
      status: 'collecting',
      lines: insertedLines,
    );
  }

  Future<PlannedRoute?> planRouteForBatch({
    required String batchId,
    required double startLat,
    required double startLng,
  }) async {
    final batch = await _client
        .from('volunteer_purchase_batches')
        .select('id, location_point_id, volunteer_purchase_batch_lines(category_label, brand_label, aggregated_quantity, unit_label)')
        .eq('id', batchId)
        .maybeSingle();
    if (batch == null) return null;

    final locId = batch['location_point_id']?.toString();
    final storesRaw = await _client
        .from('purchase_locations')
        .select('id, name, lat, lng')
        .eq('is_active', true);
    final stores = <GeoPoint>[];
    for (final s in List<dynamic>.from(storesRaw as List? ?? const [])) {
      if (s is! Map) continue;
      final lat = (s['lat'] as num?)?.toDouble();
      final lng = (s['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      stores.add(
        GeoPoint(
          id: s['id']?.toString() ?? '',
          name: s['name']?.toString() ?? '門市',
          lat: lat,
          lng: lng,
        ),
      );
    }

    if (stores.isEmpty) return null;

    final lines = batch['volunteer_purchase_batch_lines'];
    final itemLabels = <String>[];
    if (lines is List) {
      for (final l in lines) {
        if (l is! Map) continue;
        final label = l['category_label']?.toString() ?? '';
        final qty = l['aggregated_quantity'];
        itemLabels.add('$label×$qty');
      }
    }
    if (stores.isNotEmpty && itemLabels.isNotEmpty) {
      stores[0] = GeoPoint(
        id: stores.first.id,
        name: stores.first.name,
        lat: stores.first.lat,
        lng: stores.first.lng,
        items: itemLabels,
      );
    }

    GeoPoint? hub;
    if (locId != null) {
      final hubRow = await _client
          .from('location_points')
          .select('id, name, lat, lng')
          .eq('id', locId)
          .maybeSingle();
      if (hubRow != null) {
        final hlat = (hubRow['lat'] as num?)?.toDouble();
        final hlng = (hubRow['lng'] as num?)?.toDouble();
        if (hlat != null && hlng != null) {
          hub = GeoPoint(
            id: hubRow['id']?.toString() ?? '',
            name: hubRow['name']?.toString() ?? '據點',
            lat: hlat,
            lng: hlng,
          );
        }
      }
    }

    const planner = PurchaseRoutePlanner();
    final route = planner.planNearestNeighbor(
      start: GeoPoint(id: 'start', name: '志工', lat: startLat, lng: startLng),
      stores: stores,
      returnHub: hub,
    );

    await _client.from('volunteer_purchase_batches').update({
      'planned_route_json': route.toJson(),
      'status': 'locked',
      'locked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', batchId);

    return route;
  }

  Future<List<VolunteerPurchaseBatch>> listBatches({int limit = 20}) async {
    final raw = await _client
        .from('volunteer_purchase_batches')
        .select(
          'id, location_point_id, status, planned_route_json, total_estimated_cost, '
          'volunteer_purchase_batch_lines(id, category_label, brand_label, aggregated_quantity, unit_label, completed)',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    final out = <VolunteerPurchaseBatch>[];
    for (final row in List<dynamic>.from(raw as List? ?? const [])) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final linesRaw = m['volunteer_purchase_batch_lines'];
      final lines = <VolunteerPurchaseBatchLine>[];
      if (linesRaw is List) {
        for (final l in linesRaw) {
          if (l is! Map) continue;
          lines.add(
            VolunteerPurchaseBatchLine(
              id: l['id']?.toString() ?? '',
              categoryLabel: l['category_label']?.toString() ?? '',
              brandLabel: l['brand_label']?.toString(),
              aggregatedQuantity: (l['aggregated_quantity'] as num?)?.toInt() ?? 0,
              unitLabel: l['unit_label']?.toString(),
              completed: l['completed'] == true,
            ),
          );
        }
      }
      out.add(
        VolunteerPurchaseBatch(
          id: m['id']?.toString() ?? '',
          locationPointId: m['location_point_id']?.toString() ?? '',
          status: m['status']?.toString() ?? 'collecting',
          lines: lines,
          plannedRouteJson: m['planned_route_json'] is Map
              ? Map<String, dynamic>.from(m['planned_route_json'] as Map)
              : null,
          totalEstimatedCost: (m['total_estimated_cost'] as num?)?.toDouble(),
        ),
      );
    }
    return out;
  }
}
