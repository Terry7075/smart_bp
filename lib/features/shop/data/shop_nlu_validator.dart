import 'package:smart_bp/features/shop/data/product_catalog.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

/// 白名單驗證 Edge / 規則 NLU 輸出。
abstract final class ShopNluValidator {
  static const confidenceThreshold = 0.75;

  static ShopNluResult validate(ShopNluResult raw, {ProductCatalog? catalog}) {
    final cat = catalog ?? ProductCatalog.instance;
    var result = raw;
    final missing = <String>[...raw.missingFields];

    if (raw.wantsLastPurchase) {
      return result.copyWith(missingFields: missing);
    }

    final key = raw.categoryKey;
    if (key == null || key == 'unknown') {
      if (!missing.contains('category')) missing.add('category');
    } else if (cat.categoryByKey(key) == null) {
      if (!missing.contains('category')) missing.add('category');
    }

    if (raw.brandName == null &&
        raw.productItemId == null &&
        raw.pricePreference == null &&
        !raw.wantsLastPurchase) {
      if (!missing.contains('brand')) missing.add('brand');
    }

    final catObj = key != null ? cat.categoryByKey(key) : null;
    if (catObj != null &&
        (catObj.key == 'tissue' || catObj.key == 'detergent') &&
        raw.spec == null &&
        raw.productItemId == null) {
      if (!missing.contains('spec')) missing.add('spec');
    }

    result = result.copyWith(missingFields: missing);
    return result;
  }
}
