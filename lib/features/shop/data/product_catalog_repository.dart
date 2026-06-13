import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/product_catalog.dart';

/// 從 Supabase 載入商品目錄（失敗時回退 [ProductCatalog.instance]）。
class ProductCatalogRepository {
  const ProductCatalogRepository();

  Future<ProductCatalog> loadCatalog() async {
    try {
      final cats = await Supabase.instance.client
          .from('product_categories')
          .select('id, key, label, default_unit_label, keywords')
          .order('sort_order');
      if (cats.isEmpty) {
        return ProductCatalog.instance;
      }
      // 完整 DB 驅動目錄可在此擴充；目前以內建模板為準。
      return ProductCatalog.instance;
    } catch (_) {
      return ProductCatalog.instance;
    }
  }
}
