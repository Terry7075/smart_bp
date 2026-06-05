import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/fulfillment_status.dart';

class FulfillmentRepository {
  FulfillmentRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> updateStatus({
    required String itemId,
    required ItemFulfillmentStatus status,
    String? substituteItemId,
    double? actualUnitPrice,
    String? note,
  }) async {
    await _client.rpc(
      'update_item_fulfillment',
      params: {
        'p_item_id': itemId,
        'p_new_status': status.value,
        'p_substitute_item_id': substituteItemId,
        'p_actual_unit_price': actualUnitPrice,
        'p_note': note,
      },
    );
  }

  Future<void> acceptItems(List<String> itemIds) async {
    for (final id in itemIds) {
      await updateStatus(itemId: id, status: ItemFulfillmentStatus.accepted);
    }
  }
}
