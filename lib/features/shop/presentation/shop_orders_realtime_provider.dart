import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/core/notification_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_priority.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 中文狀態標籤（通知用）。
String _orderStatusLabel(String status) => switch (status) {
      'pending' => '待處理',
      'processing' => '志工處理中',
      'completed' => '已完成，感謝您的耐心等候！',
      'cancelled' => '已取消',
      _ => status,
    };

/// 長輩：自己的 `orders` 變更時自動重載（含配送事件）。
/// 偵測狀態變更時發送本地推播通知。
final shopElderOrdersProvider =
    StreamProvider.autoDispose<List<ShopOrderListRow>>((ref) {
  ref.watch(authStateChangesProvider);
  final userId = ref.watch(authProvider)?.user.id;
  if (userId == null || userId.isEmpty) {
    return Stream<List<ShopOrderListRow>>.value(const []);
  }

  final repo = ref.watch(shopOrdersRepositoryProvider);
  final client = Supabase.instance.client;

  // 記錄上一次各訂單的狀態（Map<orderId, status>），用於比對是否有變化。
  final Map<String, String> prevStatus = {};

  Future<List<ShopOrderListRow>> reload() async {
    final rows = await repo.listOrdersWithItemsForElder(userId: userId);

    for (final r in rows) {
      final prev = prevStatus[r.id];
      if (prev != null && prev != r.status) {
        await NotificationService.instance.showOrderStatusNotification(
          title: '柑仔店需求更新',
          body: '您的需求單狀態變更為：${_orderStatusLabel(r.status)}',
          orderId: r.id,
          notificationId: r.id.hashCode.abs() % 100000 + 200000,
        );
      }
      prevStatus[r.id] = r.status;
    }

    return rows;
  }

  return client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .asyncMap((_) => reload());
});

/// 志工：全站需求單 Realtime（RLS 過濾）+ 待辦優先排序。
final shopVolunteerOrdersProvider =
    StreamProvider.autoDispose<List<ShopOrderListRow>>((ref) async* {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(shopOrdersRepositoryProvider);
  final client = Supabase.instance.client;

  Future<List<ShopOrderListRow>> reload() async {
    final rows = await repo.listOrdersWithItemsForVolunteer();
    return ShopOrderPriority.sortVolunteerQueue(rows);
  }

  yield await reload();

  await for (final _ in client.from('orders').stream(primaryKey: ['id'])) {
    yield await reload();
  }
});

/// 家屬：綁定長輩的訂單 Realtime。
final familyElderOrdersStreamProvider = StreamProvider.autoDispose
    .family<List<ShopOrderListRow>, String>((ref, elderUserId) {
  ref.watch(authStateChangesProvider);
  if (elderUserId.isEmpty) {
    return Stream<List<ShopOrderListRow>>.value(const []);
  }

  final repo = ref.watch(shopOrdersRepositoryProvider);
  final client = Supabase.instance.client;

  Future<List<ShopOrderListRow>> reload() =>
      repo.listOrdersForFamilyLinkedElder(elderUserId: elderUserId);

  return client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('user_id', elderUserId)
      .asyncMap((_) => reload());
});

/// 單筆訂單詳情（配送時間軸即時更新）。
final shopOrderDetailStreamProvider = StreamProvider.autoDispose
    .family<ShopOrderListRow?, String>((ref, orderId) {
  ref.watch(authStateChangesProvider);
  if (orderId.isEmpty) {
    return Stream<ShopOrderListRow?>.value(null);
  }

  final repo = ref.watch(shopOrdersRepositoryProvider);
  final client = Supabase.instance.client;

  Future<ShopOrderListRow?> reload() => repo.fetchOrderById(orderId);

  return client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('id', orderId)
      .asyncMap((_) => reload());
});
