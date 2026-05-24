import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

final class PriceReference {
  const PriceReference({
    required this.id,
    required this.productName,
    this.productId,
    this.unitPrice,
    this.unitLabel,
    this.category,
  });

  final String id;
  final String? productId;
  final String productName;
  final double? unitPrice;
  final String? unitLabel;
  final String? category;
}

final class PriceReferencesRepository {
  const PriceReferencesRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<PriceReference>> listAll({int limit = 200}) async {
    try {
      final raw = await _client
          .from('price_references')
          .select()
          .order('product_name')
          .limit(limit);
      final list = List<dynamic>.from(raw as List? ?? const []);
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return PriceReference(
          id: m['id']?.toString() ?? '',
          productId: m['product_id']?.toString(),
          productName: m['product_name']?.toString() ?? '',
          unitPrice: (m['unit_price'] as num?)?.toDouble(),
          unitLabel: m['unit_label']?.toString(),
          category: m['category']?.toString(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<PriceReference?> findByName(String name) async {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final all = await listAll();
    PriceReference? best;
    var bestScore = 0;
    for (final p in all) {
      final pn = p.productName.toLowerCase();
      if (pn == needle) return p;
      if (pn.contains(needle) || needle.contains(pn)) {
        final score = needle.length;
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
    return best;
  }

  /// 從內建商品目錄同步至 price_references（表空或管理員首次載入）。
  Future<void> seedFromProducts(List<ShopProduct> products) async {
    try {
      final count = await _client.from('price_references').select('id').limit(1);
      if (List.from(count as List).isNotEmpty) return;

      final rows = products
          .where((p) => p.name.trim().isNotEmpty)
          .map(
            (p) => {
              'product_id': p.id,
              'product_name': p.name,
              if (p.unitPrice != null) 'unit_price': p.unitPrice,
              if (p.unitLabel != null) 'unit_label': p.unitLabel,
              'category': p.category,
              'source_note': '柑仔店目錄同步',
            },
          )
          .toList();
      if (rows.isEmpty) return;
      await _client.from('price_references').insert(rows);
    } catch (_) {
      // 表未建立時略過
    }
  }
}
