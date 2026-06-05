import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

/// 呼叫 RPC `resolve_product_item` 補齊 [ShopNluResult.productItemId]。
class ProductItemResolver {
  ProductItemResolver({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ShopNluResult> enrich(ShopNluResult result) async {
    if (result.productItemId != null && result.productItemId!.isNotEmpty) {
      return result;
    }
    try {
      final id = await _client.rpc(
        'resolve_product_item',
        params: {
          if (result.categoryKey != null) 'p_category_key': result.categoryKey,
          if (result.brandName != null) 'p_brand_name': result.brandName,
          if (result.spec != null) 'p_spec': result.spec,
          if (result.rawUtterance != null) 'p_alias_term': result.rawUtterance,
        },
      );
      final itemId = id?.toString();
      if (itemId == null || itemId.isEmpty) return result;
      return result.copyWith(productItemId: itemId);
    } catch (_) {
      return result;
    }
  }
}
