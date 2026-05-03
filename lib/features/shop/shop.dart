/// 物資採購／柑仔店參考模組（僅含 `lib/features/shop` 內檔案）。
///
/// **接上畫面**：在既有頁面（例如首頁底部「柑仔店」或路由）自行導向 [ShopPage]，例如：
/// `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShopPage()));`
///
/// **更新商品**：編輯 [shopSeedJson]（`data/shop_seed_json.dart`），貼上 Comet 輸出的 JSON 陣列。
library;

export 'data/shop_seed_json.dart';
export 'domain/shop_product.dart';
export 'presentation/shop_page.dart';
export 'presentation/shop_products_provider.dart';
