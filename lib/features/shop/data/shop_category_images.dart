/// 各商品分類的 fallback 圖示 URL（Flaticon CDN，長期穩定）。
///
/// 用途：當商品本身 imageUrl 壞掉（或為 null）時，顯示對應分類圖示。
/// 圖示皆為 128x128 PNG，免費 Flaticon Basic License，僅供 Demo 展示用。
///
/// 使用方式：
/// ```dart
/// final url = ShopCategoryImages.urlForCategory(product.category);
/// if (url != null) Image.network(url) else Icon(Icons.shopping_bag_outlined);
/// ```
class ShopCategoryImages {
  ShopCategoryImages._();

  static const Map<String, String> _urls = {
    '衛生紙':
        'https://cdn-icons-png.flaticon.com/128/2910/2910913.png',
    '清潔用品':
        'https://cdn-icons-png.flaticon.com/128/2182/2182968.png',
    '米糧':
        'https://cdn-icons-png.flaticon.com/128/2927/2927347.png',
    '雞蛋相關':
        'https://cdn-icons-png.flaticon.com/128/2674/2674464.png',
    '泡麵/麵食':
        'https://cdn-icons-png.flaticon.com/128/5787/5787008.png',
    '營養補給':
        'https://cdn-icons-png.flaticon.com/128/2942/2942058.png',
    '保健用品':
        'https://cdn-icons-png.flaticon.com/128/2913/2913136.png',
    '其他':
        'https://cdn-icons-png.flaticon.com/128/1170/1170678.png',
  };

  /// 回傳分類對應的 fallback 圖示 URL；未定義分類回傳 null（顯示 placeholder icon）。
  static String? urlForCategory(String? category) {
    if (category == null || category.trim().isEmpty) return null;
    return _urls[category.trim()] ?? _urls['其他'];
  }

  /// 所有已定義的分類。
  static List<String> get categories => _urls.keys.toList();
}
