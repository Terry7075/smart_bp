/// 物資採購／柑仔店參考模組（僅含 `lib/features/shop` 內檔案）。
///
/// **接上畫面**：長輩端請使用路由 `/shop`（見 [ShopRoutePage]），會自動套用長輩角色守門；
/// 或 `context.push('/shop')`。
///
/// **更新商品**：編輯 [shopSeedJson]（`data/shop_seed_json.dart`），貼上 Comet 輸出的 JSON 陣列。
///
/// **目錄沒列的商品**：長輩可在 [ShopPage] 用手動區塊填品牌、品名、規格、全聯搜尋關鍵字（選填）等，與目錄品項一併送出，寫入同一張 `orders`／`order_items`。
library;

export 'data/shop_seed_json.dart';
export 'domain/shop_product.dart';
export 'presentation/shop_page.dart';
export 'presentation/shop_route_page.dart';
export 'presentation/shop_products_provider.dart';
