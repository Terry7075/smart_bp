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
