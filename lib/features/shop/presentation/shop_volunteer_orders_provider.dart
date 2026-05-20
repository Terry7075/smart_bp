import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';

/// 志工端：柑仔店／全聯參考需求單列表（Supabase `orders` + `order_items`）。
final shopVolunteerOrdersProvider =
    FutureProvider.autoDispose<List<ShopOrderListRow>>((ref) async {
  final repo = ref.watch(shopOrdersRepositoryProvider);
  return repo.listOrdersWithItemsForVolunteer();
});
