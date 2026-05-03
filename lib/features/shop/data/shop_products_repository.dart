import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:smart_bp/features/shop/data/shop_seed_json.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

/// 從本模組內建 JSON 字串載入柑仔店參考商品（Comet 結果請貼入 [shopSeedJson]）。
///
/// 若存在資源檔 [product_images.json]（`npm run scrape:px-images` 產生），會依全聯
/// `/product/{id}` 對應的 `product_id` 自動覆寫 [ShopProduct.imageUrl]，無須手動貼連結。
class ShopProductsRepository {
  static const String _scrapedImagesAsset = 'lib/features/shop/data/product_images.json';

  Future<List<ShopProduct>> load() async {
    final products = shopSeedJson.trim().isNotEmpty
        ? ShopProduct.listFromJsonString(shopSeedJson)
        : ShopProduct.listFromCometText(shopSeedCometText);
    final overrides = await _loadPxScrapedImageOverrides();
    if (overrides.isEmpty) return products;
    return products.map((p) => _applyScrapedImage(p, overrides)).toList();
  }

  ShopProduct _applyScrapedImage(ShopProduct p, Map<String, String> overrides) {
    final id = p.productId ?? _pxProductIdFromUrl(p.sourceUrl);
    if (id == null || id.isEmpty) return p;
    final img = overrides[id];
    if (img == null || img.isEmpty) return p;
    return p.copyWith(imageUrl: img);
  }

  String? _pxProductIdFromUrl(String? url) => ShopProduct.parsePxProductId(url);

  /// 僅採用爬蟲判定「頁面標題與種子品名對得起來」的列。
  ///
  /// 先前只要 `ok` 就覆寫時，大量 `detail_unverified`（例如全聯頁退成總覽、抓到同一張占位圖）
  /// 會讓好多 SKU 顯示同一張錯圖；其餘商品會退回種子的 `imgURL`。
  static bool _acceptScrapedRow(Map<String, dynamic> row) {
    if (row['ok'] != true) return false;
    if (row['mapped_correct'] != true) return false;
    final img = row['image_url'];
    return img != null && img.toString().trim().isNotEmpty;
  }

  Future<Map<String, String>> _loadPxScrapedImageOverrides() async {
    try {
      final raw = await rootBundle.loadString(_scrapedImagesAsset);
      final decoded = json.decode(raw);
      if (decoded is! List<dynamic>) return {};
      final map = <String, String>{};
      for (final e in decoded) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        if (!_acceptScrapedRow(row)) continue;
        final id = row['product_id']?.toString().trim();
        final url = row['image_url']?.toString().trim();
        if (id == null || id.isEmpty || url == null || url.isEmpty) continue;
        map[id] = url;
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
