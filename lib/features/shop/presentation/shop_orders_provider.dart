import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/data/shop_orders_repository.dart';

final shopOrdersRepositoryProvider = Provider<ShopOrdersRepository>(
  (ref) => const ShopOrdersRepository(),
);

/// 長輩訂單詳情：品項級履行狀態（來自 demand_record_items）。
final orderItemFulfillmentProvider = FutureProvider.autoDispose
    .family<List<DemandItemFulfillmentRow>, String>((ref, orderId) {
  return ref.read(demandRecordsRepositoryProvider).fetchItemFulfillmentForOrder(orderId);
});

