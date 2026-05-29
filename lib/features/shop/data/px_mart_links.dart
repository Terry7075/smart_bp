import 'package:smart_bp/features/shop/domain/shop_product.dart';

/// 導向 pxbox 搜尋結果頁，關鍵字為 [ShopProduct.pxMartSearchKeyword]。
Uri buildPxMartSearchResultUri(ShopProduct product) {
  final kw = product.pxMartSearchKeyword.trim();
  if (kw.isEmpty) {
    return Uri.https('pxbox.es.pxmart.com.tw', '/', {'openExternalBrowser': '1'});
  }
  return Uri.https('pxbox.es.pxmart.com.tw', '/search/result', {
    'keyword': kw,
    'openExternalBrowser': '1',
  });
}

/// 建立全聯電商搜尋或精準商品頁 URL。
///
/// 優先順序：
///   1. [externalUrl]（精準商品頁）若不為空則直接回傳
///   2. [externalKeyword]（手填搜尋關鍵字）
///   3. [name]（商品名稱）
///
/// 最終產生全聯 pxbox 搜尋網址，可直接用 [Uri.parse] 開啟。
String buildPxMartUrl({
  required String name,
  String? externalKeyword,
  String? externalUrl,
}) {
  final url = externalUrl?.trim();
  if (url != null && url.isNotEmpty) return url;

  final kw = externalKeyword?.trim();
  final keyword = (kw != null && kw.isNotEmpty) ? kw : name.trim();
  if (keyword.isEmpty) {
    return 'https://pxbox.es.pxmart.com.tw/?openExternalBrowser=1';
  }
  final encoded = Uri.encodeComponent(keyword);
  return 'https://pxbox.es.pxmart.com.tw/search/result?keyword=$encoded&openExternalBrowser=1';
}

/// 由商品名稱或 productName 快照建立全聯搜尋 Uri（志工端使用）。
Uri buildPxMartUriFromName(String productName) {
  final kw = productName.trim();
  if (kw.isEmpty) {
    return Uri.parse('https://pxbox.es.pxmart.com.tw/?openExternalBrowser=1');
  }
  return Uri.https('pxbox.es.pxmart.com.tw', '/search/result', {
    'keyword': kw,
    'openExternalBrowser': '1',
  });
}
