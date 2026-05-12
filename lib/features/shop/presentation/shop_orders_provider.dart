import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/data/shop_orders_repository.dart';

final shopOrdersRepositoryProvider = Provider<ShopOrdersRepository>(
  (ref) => const ShopOrdersRepository(),
);

