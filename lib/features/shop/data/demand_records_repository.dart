import 'package:smart_bp/features/shop/data/shop_orders_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class DemandRecordItem {
  const DemandRecordItem({
    required this.id,
    required this.productName,
    required this.quantity,
    this.productId,
    this.unitPrice,
    this.cancelled = false,
  });

  final String id;
  final String? productId;
  final String productName;
  final int quantity;
  final double? unitPrice;
  final bool cancelled;
}

final class DemandRecord {
  const DemandRecord({
    required this.id,
    required this.userId,
    required this.status,
    required this.items,
    this.locationPointId,
    this.locationName,
    this.orderId,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String status;
  final List<DemandRecordItem> items;
  final String? locationPointId;
  final String? locationName;
  final String? orderId;
  final DateTime updatedAt;

  List<DemandRecordItem> get activeItems =>
      items.where((i) => !i.cancelled).toList();
}

final class DemandRecordsRepository {
  const DemandRecordsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Future<DemandRecord?> getOrCreateDraft({
    required String userId,
    String? locationPointId,
  }) async {
    final existing = await _client
        .from('demand_records')
        .select('id, user_id, status, location_point_id, order_id, updated_at')
        .eq('user_id', userId)
        .eq('status', 'draft')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      return _loadRecord(Map<String, dynamic>.from(existing));
    }

    final locId = locationPointId ?? await fetchElderLocationPointId(userId);

    final inserted = await _client
        .from('demand_records')
        .insert({
          'user_id': userId,
          if (locId != null && locId.isNotEmpty) 'location_point_id': locId,
          'status': 'draft',
        })
        .select('id, user_id, status, location_point_id, order_id, updated_at')
        .single();

    return _loadRecord(Map<String, dynamic>.from(inserted));
  }

  Future<DemandRecord> addLines({
    required String userId,
    required List<({String productName, int quantity, String? productId, double? unitPrice})> lines,
  }) async {
    final draft = await getOrCreateDraft(userId: userId);
    if (draft == null) throw const AuthException('無法建立需求草稿');

    for (final line in lines) {
      await _client.from('demand_record_items').insert({
        'demand_record_id': draft.id,
        'product_name': line.productName,
        'quantity': line.quantity,
        if (line.productId != null) 'product_id': line.productId,
        if (line.unitPrice != null) 'unit_price': line.unitPrice,
      });
    }

    await _client
        .from('demand_records')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', draft.id);

    return (await _loadRecordById(draft.id))!;
  }

  Future<DemandRecord?> cancelProduct({
    required String userId,
    required String productName,
  }) async {
    final draft = await getOrCreateDraft(userId: userId);
    if (draft == null) return null;

    final needle = productName.trim().toLowerCase();
    for (final item in draft.items) {
      if (item.cancelled) continue;
      if (item.productName.toLowerCase().contains(needle) ||
          needle.contains(item.productName.toLowerCase())) {
        await _client
            .from('demand_record_items')
            .update({'cancelled': true})
            .eq('id', item.id);
      }
    }

    return _loadRecordById(draft.id);
  }

  /// 將目前草稿轉為正式 `orders` 並標記 submitted。
  Future<String> submitDraftToOrders({
    required String userId,
    required ShopOrdersRepository ordersRepo,
  }) async {
    final draft = await getOrCreateDraft(userId: userId);
    if (draft == null) {
      throw const AuthException('無法讀取需求草稿');
    }
    final active = draft.activeItems;
    if (active.isEmpty) {
      throw const AuthException('請先記錄至少一項需求');
    }

    final orderId = await ordersRepo.createOrderFromDraftLines(
      userId: userId,
      locationPointId: draft.locationPointId,
      lines: [
        for (final i in active)
          (
            productId: i.productId ?? '',
            productName: i.productName,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
          ),
      ],
    );

    await _client.from('demand_records').update({
      'status': 'submitted',
      'order_id': orderId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', draft.id);

    return orderId;
  }

  Future<String?> fetchElderLocationPointId(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('location_point_id')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return row['location_point_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<DemandRecord>> listDraftsForVolunteer({int limit = 50}) async {
    final raw = await _client
        .from('demand_records')
        .select(
          'id, user_id, status, location_point_id, order_id, updated_at, '
          'location_points(name), '
          'demand_record_items(id, product_id, product_name, quantity, unit_price, cancelled)',
        )
        .inFilter('status', ['draft', 'submitted'])
        .order('updated_at', ascending: false)
        .limit(limit);

    final list = List<dynamic>.from(raw as List? ?? const []);
    final out = <DemandRecord>[];
    for (final e in list) {
      if (e is! Map) continue;
      final r = _parseRecordRow(Map<String, dynamic>.from(e));
      if (r != null) out.add(r);
    }
    return out;
  }

  Future<DemandRecord?> _loadRecordById(String id) async {
    final raw = await _client
        .from('demand_records')
        .select(
          'id, user_id, status, location_point_id, order_id, updated_at, '
          'location_points(name), '
          'demand_record_items(id, product_id, product_name, quantity, unit_price, cancelled)',
        )
        .eq('id', id)
        .maybeSingle();
    if (raw == null) return null;
    return _parseRecordRow(Map<String, dynamic>.from(raw));
  }

  Future<DemandRecord?> _loadRecord(Map<String, dynamic> head) async {
    return _loadRecordById(head['id']?.toString() ?? '');
  }

  DemandRecord? _parseRecordRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final userId = row['user_id']?.toString();
    if (id == null || userId == null) return null;

    final loc = row['location_points'];
    String? locName;
    if (loc is Map) locName = loc['name']?.toString();

    final itemsRaw = row['demand_record_items'];
    final items = <DemandRecordItem>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        items.add(
          DemandRecordItem(
            id: m['id']?.toString() ?? '',
            productId: m['product_id']?.toString(),
            productName: m['product_name']?.toString() ?? '',
            quantity: (m['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (m['unit_price'] as num?)?.toDouble(),
            cancelled: m['cancelled'] == true,
          ),
        );
      }
    }

    return DemandRecord(
      id: id,
      userId: userId,
      status: row['status']?.toString() ?? 'draft',
      items: items,
      locationPointId: row['location_point_id']?.toString(),
      locationName: locName,
      orderId: row['order_id']?.toString(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
