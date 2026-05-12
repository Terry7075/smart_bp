import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

final class ShopOrdersRepository {
  const ShopOrdersRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// 建立一筆「需求單」（Demo 版）：會寫入 orders 與 order_items。
  ///
  /// 需求端情境：志工代墊前先收集需求；因此目前只建單，不處理金流。
  Future<String> createOrder({
    required String userId,
    required List<ShopProduct> products,
    required Map<String, int> quantitiesByProductId,
    String? note,
  }) async {
    final items = <Map<String, dynamic>>[];
    for (final p in products) {
      final qty = quantitiesByProductId[p.id] ?? 0;
      if (qty <= 0) continue;
      items.add({
        'product_id': p.id,
        'product_name': p.name,
        'quantity': qty,
        if (p.unitPrice != null) 'unit_price': p.unitPrice,
      });
    }

    if (items.isEmpty) {
      throw const AuthException('無可送出的品項');
    }

    final inserted = await _client
        .from('orders')
        .insert({
          'user_id': userId,
          'status': 'submitted',
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
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
}

