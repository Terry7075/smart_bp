import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';

/// 長輩常購品項（依過去訂單統計）。
final shopFrequentProductsProvider =
    FutureProvider.autoDispose<List<FrequentShopItem>>((ref) async {
  final userId = ref.watch(authProvider)?.user.id;
  if (userId == null || userId.isEmpty) return const [];
  return ref
      .read(shopOrdersRepositoryProvider)
      .frequentItemsForElder(userId: userId);
});
