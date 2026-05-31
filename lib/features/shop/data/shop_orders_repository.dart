import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

final class ShopOrdersRepository {
  const ShopOrdersRepository();

  SupabaseClient get _client => Supabase.instance.client;

  static const String initialOrderStatus = String.fromEnvironment(
    'SHOP_ORDER_STATUS',
    defaultValue: 'pending',
  );

  static const _orderSelect = '''
id, user_id, status, created_at, total_amount, is_urgent,
assigned_volunteer_id, delivered_at, delivery_issue, location_point_id,
location_points(name),
order_items(product_id, product_name, quantity, unit_price, price_at_time, category, unit_label, brand, spec, supply_category_key, template_option_id, reference_note),
order_delivery_events(id, order_id, event_type, note, created_at)
''';

  Future<List<ShopOrderListRow>> listOrdersWithItemsForVolunteer({
    int limit = 80,
  }) async {
    final raw = await _client
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false)
        .limit(limit);

    return _rowsFromList(raw, enrichElder: true);
  }

  Future<List<ShopOrderListRow>> listOrdersWithItemsForElder({
    required String userId,
    int limit = 80,
  }) async {
    final raw = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _rowsFromList(raw, enrichElder: false);
  }

  /// 家屬：讀取綁定長輩的訂單（依 RLS `orders_select_family`）。
  Future<List<ShopOrderListRow>> listOrdersForFamilyLinkedElder({
    required String elderUserId,
    int limit = 40,
  }) async {
    final raw = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('user_id', elderUserId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _rowsFromList(raw, enrichElder: false);
  }

  /// 管理員：全部訂單（依 RLS `orders_select_admin`）。
  Future<List<ShopOrderListRow>> listOrdersForAdmin({int limit = 200}) async {
    final raw = await _client
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false)
        .limit(limit);

    return _rowsFromList(raw, enrichElder: true);
  }

  Future<ShopOrderListRow?> fetchOrderById(String orderId) async {
    final raw = await _client
        .from('orders')
        .select(_orderSelect)
        .eq('id', orderId)
        .maybeSingle();
    if (raw == null) return null;
    final rows = await _rowsFromList([raw], enrichElder: true);
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> createOrder({
    required String userId,
    required List<ShopProduct> products,
    required Map<String, int> quantitiesByProductId,
    bool isUrgent = false,
  }) async {
    final items = <Map<String, dynamic>>[];
    var totalAmount = 0.0;
    for (final p in products) {
      final qty = quantitiesByProductId[p.id] ?? 0;
      if (qty <= 0) continue;
      totalAmount += (p.unitPrice ?? 0) * qty;
      final row = <String, dynamic>{
        'product_id': p.id,
        'product_name': p.name,
        'quantity': qty,
        'price_at_time': (p.unitPrice ?? 0).round(),
        'category': p.category,
        if (p.unitLabel != null && p.unitLabel!.isNotEmpty) 'unit_label': p.unitLabel,
      };
      if (p.unitPrice != null) row['unit_price'] = p.unitPrice;
      items.add(row);
    }

    if (items.isEmpty) {
      throw const AuthException('無可送出的品項');
    }

    final inserted = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'status': initialOrderStatus,
          'total_amount': totalAmount.round(),
          'is_urgent': isUrgent,
        })
        .select('id')
        .single();

    final orderId = inserted['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw const AuthException('建立訂單失敗：未取得訂單編號');
    }

    for (final item in items) {
      item['order_id'] = orderId;
    }
    await _client.from('order_items').insert(items);

    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: ShopOrderStatus.created,
      note: isUrgent ? '長輩標記為【緊急需求】已送出物資需求單' : '長輩已送出物資需求單',
    );

    return orderId;
  }

  /// 由 demand_records 草稿品項建立正式 orders（第五章語音／小幫手記錄後送出）。
  Future<String> createOrderFromDraftLines({
    required String userId,
    required List<SupplyLineSnapshot> lines,
    String? locationPointId,
  }) async {
    if (lines.isEmpty) {
      throw const AuthException('草稿沒有可送出的品項');
    }

    var totalAmount = 0.0;
    final orderItems = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.quantity <= 0) continue;
      final price = line.unitPrice ?? 0;
      totalAmount += price * line.quantity;
      orderItems.add({
        ...line.toInsertMap(),
        'price_at_time': price.round(),
      });
    }

    final insertRow = <String, dynamic>{
      'user_id': userId,
      'status': initialOrderStatus,
      'total_amount': totalAmount.round(),
    };
    if (locationPointId != null && locationPointId.isNotEmpty) {
      insertRow['location_point_id'] = locationPointId;
    }

    final inserted = await _client
        .from('orders')
        .insert(insertRow)
        .select('id')
        .single();

    final orderId = inserted['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw const AuthException('建立訂單失敗');
    }

    for (final item in orderItems) {
      item['order_id'] = orderId;
    }
    await _client.from('order_items').insert(orderItems);

    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: ShopOrderStatus.created,
      note: '長輩已送出物資需求單（含語音草稿）',
    );

    return orderId;
  }

  /// 志工接單：pending → processing + accepted 事件。
  Future<void> acceptOrderByVolunteer({
    required String orderId,
    required String volunteerId,
  }) async {
    await updateOrderStatusByVolunteer(
      orderId: orderId,
      currentStatus: 'pending',
      newStatus: 'processing',
    );
    await _client.from('orders').update({
      'assigned_volunteer_id': volunteerId,
    }).eq('id', orderId);
    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: ShopOrderStatus.accepted,
      note: '志工已接單，將協助採買',
      createdBy: volunteerId,
    );
  }

  /// 配送中繼步驟（不改 orders.status，只加事件）。
  Future<void> addDeliveryMilestone({
    required String orderId,
    required String eventType,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: eventType,
      note: note,
      createdBy: uid,
    );
  }

  /// 標記送達：processing → completed。
  Future<void> completeDelivery({
    required String orderId,
    String? note,
  }) async {
    await updateOrderStatusByVolunteer(
      orderId: orderId,
      currentStatus: 'processing',
      newStatus: 'completed',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('orders').update({
      'delivered_at': now,
    }).eq('id', orderId);
    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: ShopOrderStatus.delivered,
      note: note ?? '物資已送達長輩',
    );
  }

  Future<void> reportDeliveryIssue({
    required String orderId,
    required String issueNote,
  }) async {
    await _client.from('orders').update({
      'delivery_issue': issueNote,
    }).eq('id', orderId);
    await _insertDeliveryEvent(
      orderId: orderId,
      eventType: ShopOrderStatus.issue,
      note: issueNote,
    );
  }

  Future<void> _insertDeliveryEvent({
    required String orderId,
    required String eventType,
    String? note,
    String? createdBy,
  }) async {
    try {
      await _client.from('order_delivery_events').insert({
        'order_id': orderId,
        'event_type': eventType,
        'note': note,
        'created_by': createdBy ?? _client.auth.currentUser?.id,
      });
    } catch (_) {
      // 表尚未建立時不阻擋主流程
    }
  }

  Future<void> updateOrderStatusByVolunteer({
    required String orderId,
    required String currentStatus,
    required String newStatus,
  }) async {
    const allowed = {'pending', 'processing', 'completed', 'cancelled'};
    if (!allowed.contains(newStatus)) {
      throw const AuthException('不支援的訂單狀態');
    }
    final ok = switch ((currentStatus, newStatus)) {
      ('pending', 'processing') => true,
      ('pending', 'cancelled') => true,
      ('processing', 'pending') => true,
      ('processing', 'completed') => true,
      ('processing', 'cancelled') => true,
      _ => false,
    };
    if (!ok) {
      throw AuthException('無法從「$currentStatus」變更為「$newStatus」');
    }
    await _client.from('orders').update({'status': newStatus}).eq('id', orderId);
  }

  Future<List<ShopOrderListRow>> _rowsFromList(
    dynamic raw, {
    required bool enrichElder,
  }) async {
    final list = List<dynamic>.from(raw as List? ?? const []);
    final rows = <ShopOrderListRow>[];
    final userIds = <String>{};

    for (final e in list) {
      if (e is! Map) continue;
      final row = _parseOrderRow(Map<String, dynamic>.from(e));
      if (row != null) {
        userIds.add(row.userId);
        rows.add(row);
      }
    }

    if (!enrichElder || userIds.isEmpty) return rows;

    final names = await _fetchElderNames(userIds);
    final contacts = await _fetchElderContacts(userIds);
    return rows
        .map(
          (r) => ShopOrderListRow(
            id: r.id,
            userId: r.userId,
            status: r.status,
            note: r.note,
            createdAt: r.createdAt,
            items: r.items,
            elderDisplayName: names[r.userId],
            elderPhone: contacts[r.userId],
            totalAmount: r.totalAmount,
            assignedVolunteerId: r.assignedVolunteerId,
            deliveredAt: r.deliveredAt,
            deliveryIssue: r.deliveryIssue,
            deliveryEvents: r.deliveryEvents,
            locationPointId: r.locationPointId,
            locationPointName: r.locationPointName,
          ),
        )
        .toList();
  }

  ShopOrderListRow? _parseOrderRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final userId = row['user_id']?.toString();
    if (id == null || id.isEmpty || userId == null || userId.isEmpty) {
      return null;
    }
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final deliveredRaw = row['delivered_at']?.toString();
    final loc = row['location_points'];
    String? locName;
    if (loc is Map) locName = loc['name']?.toString();
    return ShopOrderListRow(
      id: id,
      userId: userId,
      status: row['status']?.toString() ?? 'pending',
      note: null,
      createdAt: createdAt,
      items: _parseOrderItems(row['order_items']),
      totalAmount: (row['total_amount'] as num?)?.toInt(),
      assignedVolunteerId: row['assigned_volunteer_id']?.toString(),
      deliveredAt: deliveredRaw != null ? DateTime.tryParse(deliveredRaw) : null,
      deliveryIssue: row['delivery_issue']?.toString(),
      deliveryEvents: _parseDeliveryEvents(row['order_delivery_events']),
      locationPointId: row['location_point_id']?.toString(),
      locationPointName: locName,
      isUrgent: row['is_urgent'] == true,
    );
  }

  static List<OrderDeliveryEvent> _parseDeliveryEvents(dynamic raw) {
    final list = List<dynamic>.from(raw as List? ?? const []);
    final events = <OrderDeliveryEvent>[];
    for (final e in list) {
      if (e is! Map) continue;
      events.add(OrderDeliveryEvent.fromMap(Map<String, dynamic>.from(e)));
    }
    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  static List<ShopOrderItemRow> _parseOrderItems(dynamic raw) {
    final list = List<dynamic>.from(raw as List? ?? const []);
    final out = <ShopOrderItemRow>[];
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final name = row['product_name']?.toString() ?? '';
      final qty = (row['quantity'] as num?)?.toInt() ?? 0;
      if (qty <= 0) continue;
      final unit = (row['unit_price'] as num?)?.toDouble();
      final priceAtTime = (row['price_at_time'] as num?)?.toDouble();
      out.add(
        ShopOrderItemRow(
          productId: row['product_id']?.toString() ?? '',
          productName: name.isEmpty ? '（未命名）' : name,
          quantity: qty,
          unitPrice: unit ?? priceAtTime,
          category: row['category']?.toString(),
          unitLabel: row['unit_label']?.toString(),
          brand: row['brand']?.toString(),
          spec: row['spec']?.toString(),
          supplyCategoryKey: row['supply_category_key']?.toString(),
          templateOptionId: row['template_option_id']?.toString(),
          referenceNote: row['reference_note']?.toString(),
        ),
      );
    }
    return out;
  }

  Future<Map<String, String?>> _fetchElderContacts(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final res = await _client
          .from('profiles')
          .select('id,phone')
          .inFilter('id', userIds.toList());
      final map = <String, String?>{};
      for (final e in List<dynamic>.from(res as List? ?? const [])) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = m['id']?.toString();
        final phone = m['phone']?.toString().trim();
        if (id != null) map[id] = (phone != null && phone.isNotEmpty) ? phone : null;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// 常購品項（依歷史 `order_items` 加總數量，供柑仔店一鍵加購）。
  Future<List<FrequentShopItem>> frequentItemsForElder({
    required String userId,
    int orderLimit = 30,
    int maxItems = 8,
  }) async {
    final orders = await listOrdersWithItemsForElder(
      userId: userId,
      limit: orderLimit,
    );
    final qtyByProduct = <String, int>{};
    final nameByProduct = <String, String>{};
    for (final o in orders) {
      for (final item in o.items) {
        final pid = item.productId.trim();
        if (pid.isEmpty) continue;
        qtyByProduct[pid] = (qtyByProduct[pid] ?? 0) + item.quantity;
        final name = item.productName.trim();
        if (name.isNotEmpty) nameByProduct[pid] = name;
      }
    }
    final ranked = qtyByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(maxItems).map((e) {
      return FrequentShopItem(
        productId: e.key,
        productName: nameByProduct[e.key] ?? e.key,
        totalQuantity: e.value,
      );
    }).toList();
  }

  Future<Map<String, String>> _fetchElderNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final res = await _client
          .from('profiles')
          .select('id,name')
          .inFilter('id', userIds.toList());
      final map = <String, String>{};
      for (final e in List<dynamic>.from(res as List? ?? const [])) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = m['id']?.toString();
        final name = m['name']?.toString().trim();
        if (id != null && name != null && name.isNotEmpty) map[id] = name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
