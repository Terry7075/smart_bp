import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

final class ShopOrdersRepository {
  const ShopOrdersRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// 與資料庫 `orders.status`（enum `order_status`）**字面值**一致（注意大小寫）。
  ///
  /// 明德專案 enum：`pending` / `processing` / `completed` / `cancelled` → 新單用 **pending**。
  /// 若你方 DB 不同，可用：`--dart-define=SHOP_ORDER_STATUS=其他允許值`。
  static const String initialOrderStatus = String.fromEnvironment(
    'SHOP_ORDER_STATUS',
    defaultValue: 'pending',
  );

  /// 志工端：列出最近需求單（含明細），並嘗試補上長輩姓名（需 DB 允許志工讀 `profiles`）。
  Future<List<ShopOrderListRow>> listOrdersWithItemsForVolunteer({
    int limit = 80,
  }) async {
    final raw = await _client
        .from('orders')
        .select(
          'id, user_id, status, created_at, total_amount, '
          'order_items(product_id, product_name, quantity, unit_price, price_at_time)',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    final list = List<dynamic>.from(raw as List? ?? const []);

    final rows = <ShopOrderListRow>[];
    final userIds = <String>{};

    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final id = row['id']?.toString();
      final userId = row['user_id']?.toString();
      if (id == null || id.isEmpty || userId == null || userId.isEmpty) {
        continue;
      }
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final items = _parseOrderItems(row['order_items']);
      final totalAmt = (row['total_amount'] as num?)?.toInt();
      userIds.add(userId);
      rows.add(
        ShopOrderListRow(
          id: id,
          userId: userId,
          status: row['status']?.toString() ?? 'pending',
          // 明德 orders 表無 `note` 欄位；若日後新增可改回 row['note']
          note: null,
          createdAt: createdAt,
          items: items,
          totalAmount: totalAmt,
        ),
      );
    }

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
          ),
        )
        .toList();
  }

  /// 長輩端：列出自己的需求單（含明細）。
  ///
  /// 依 RLS（`orders_select_own` / `order_items_select_own`）只會讀到自己的單。
  Future<List<ShopOrderListRow>> listOrdersWithItemsForElder({
    required String userId,
    int limit = 80,
  }) async {
    final raw = await _client
        .from('orders')
        .select(
          'id, user_id, status, created_at, total_amount, '
          'order_items(product_id, product_name, quantity, unit_price, price_at_time)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = List<dynamic>.from(raw as List? ?? const []);
    final rows = <ShopOrderListRow>[];
    for (final e in list) {
      if (e is! Map) continue;
      final row = Map<String, dynamic>.from(e);
      final id = row['id']?.toString();
      final uid = row['user_id']?.toString();
      if (id == null || id.isEmpty || uid == null || uid.isEmpty) continue;
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      rows.add(
        ShopOrderListRow(
          id: id,
          userId: uid,
          status: row['status']?.toString() ?? 'pending',
          note: null,
          createdAt: createdAt,
          items: _parseOrderItems(row['order_items']),
          totalAmount: (row['total_amount'] as num?)?.toInt(),
        ),
      );
    }
    return rows;
  }

  Future<Map<String, String?>> _fetchElderContacts(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final list = userIds.toList();
      final res = await _client.from('profiles').select('id,phone').inFilter('id', list);
      final plist = List<dynamic>.from(res as List? ?? const []);
      final map = <String, String?>{};
      for (final e in plist) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = m['id']?.toString();
        final phone = m['phone']?.toString().trim();
        if (id != null && id.isNotEmpty) {
          map[id] = (phone != null && phone.isNotEmpty) ? phone : null;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> _fetchElderNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final list = userIds.toList();
      final res = await _client.from('profiles').select('id,name').inFilter('id', list);
      final plist = List<dynamic>.from(res as List? ?? const []);
      final map = <String, String>{};
      for (final e in plist) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = m['id']?.toString();
        final name = m['name']?.toString().trim();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          map[id] = name;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
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
        ),
      );
    }
    return out;
  }

  /// 建立一筆「需求單」（Demo 版）：會寫入 orders 與 order_items。
  ///
  /// 需求端情境：志工代墊前先收集需求；因此目前只建單，不處理金流。
  Future<String> createOrder({
    required String userId,
    required List<ShopProduct> products,
    required Map<String, int> quantitiesByProductId,
  }) async {
    final items = <Map<String, dynamic>>[];
    var totalAmount = 0.0;
    for (final p in products) {
      final qty = quantitiesByProductId[p.id] ?? 0;
      if (qty <= 0) continue;
      final line = (p.unitPrice ?? 0) * qty;
      totalAmount += line;
      final row = <String, dynamic>{
        'product_id': p.id,
        'product_name': p.name,
        'quantity': qty,
      };
      // 與 Supabase 常見欄位並存：
      // - unit_price（numeric，可空）
      // - price_at_time（int，部分 schema 為 NOT NULL；此處永遠填值，無單價則 0）
      row['price_at_time'] = (p.unitPrice ?? 0).round();
      if (p.unitPrice != null) row['unit_price'] = p.unitPrice;
      items.add(row);
    }

    if (items.isEmpty) {
      throw const AuthException('無可送出的品項');
    }

    // `orders.total_amount` 在明德 schema 為 NOT NULL：參考金額加總（無單價則 0）
    final totalForDb = totalAmount.round();

    final inserted = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'status': initialOrderStatus,
          'total_amount': totalForDb,
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
    return orderId;
  }

  /// 志工更新訂單狀態（Double-check／接單流程）。
  ///
  /// 允許：`pending` ↔ `processing`（可退回待處理）、`pending`/`processing` → `completed`、
  /// `pending`/`processing` → `cancelled`。
  /// 需在 Supabase 執行 `orders_volunteer_update_rls.sql` 賦予志工 `update` 權限。
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
}
