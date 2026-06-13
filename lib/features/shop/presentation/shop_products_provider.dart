import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/data/shop_products_repository.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';

final shopProductsRepositoryProvider = Provider<ShopProductsRepository>(
  (ref) => ShopProductsRepository(),
);

final shopProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  final repo = ref.watch(shopProductsRepositoryProvider);
  return repo.load();
});
