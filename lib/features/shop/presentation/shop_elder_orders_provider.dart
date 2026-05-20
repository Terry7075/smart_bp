import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';

/// 長輩端：我的需求單（Supabase `orders` + `order_items`）。
final shopElderOrdersProvider = FutureProvider.autoDispose<List<ShopOrderListRow>>((ref) async {
  final session = ref.watch(authProvider);
  final userId = session?.user.id;
  if (userId == null || userId.isEmpty) return [];
  final repo = ref.watch(shopOrdersRepositoryProvider);
  return repo.listOrdersWithItemsForElder(userId: userId);
});

