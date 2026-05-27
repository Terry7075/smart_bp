import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/shared/offline_queue/offline_queue.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/data/price_references_repository.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';

/// 五類意圖對應動作（記錄／查價／查看／取消）。
class AssistantShopActionService {
  const AssistantShopActionService({
    required DemandRecordsRepository demandRepo,
    required PriceReferencesRepository priceRepo,
  })  : _demandRepo = demandRepo,
        _priceRepo = priceRepo;

  final DemandRecordsRepository _demandRepo;
  final PriceReferencesRepository _priceRepo;

  static const _navShop = AssistantNavAction(label: '前往柑仔店', route: '/shop');
  static const _navShopOrders =
      AssistantNavAction(label: '查看需求紀錄', route: '/shop/orders');
  static const _navPrices =
      AssistantNavAction(label: '全聯價格參考', route: '/shop/prices');

  Future<AssistantReply> handle({
    required ShopIntentClassification classification,
    required String userId,
    required AssistantSnapshot snapshot,
  }) async {
    final intent = classification.intent;
    final slots = classification.slots;
    final layerNote =
        '（意圖：${classification.intentLabel}，${classification.layer}，'
        '${classification.elapsedMs}ms）';

    switch (intent) {
      case AssistantShopIntent.recordDemand:
        return _recordDemand(userId, slots, layerNote);
      case AssistantShopIntent.queryPrice:
        return _queryPrice(slots, layerNote);
      case AssistantShopIntent.viewRecorded:
        return _viewRecorded(userId, snapshot, layerNote);
      case AssistantShopIntent.cancelDemand:
        return _cancelDemand(userId, slots, layerNote);
      case AssistantShopIntent.casual:
        return AssistantReply(
          text: '您好！想記需求可以說「我要買米和醬油」，查價說「雞蛋多少錢」。$layerNote',
          actions: const [_navShop, _navPrices],
        );
    }
  }

  Future<AssistantReply> _recordDemand(
    String userId,
    ShopIntentSlots? slots,
    String layerNote,
  ) async {
    final lines = slots?.lines ?? const [];
    if (lines.isEmpty) {
      return AssistantReply(
        text: '想買什麼可以跟我說，例如「我要買兩瓶醬油」。$layerNote',
        actions: const [_navShop],
      );
    }
    try {
      final record = await _demandRepo.addLines(
        userId: userId,
        lines: [
          for (final l in lines)
            (
              productName: l.productName,
              quantity: l.quantity,
              productId: null as String?,
              unitPrice: null as double?,
            ),
        ],
      );
      final summary = record.activeItems
          .map((i) => '${i.productName}×${i.quantity}')
          .join('、');
      return AssistantReply(
        text: '好，已幫您記在需求草稿裡：$summary。\n'
            '要正式送出請到柑仔店確認，或跟我說「我剛剛說要買什麼」查看。$layerNote',
        actions: const [_navShop, _navShopOrders],
      );
    } catch (e) {
      // 網路失敗 → 寫入離線佇列
      if (kDebugMode) debugPrint('[Assistant] Supabase failed, enqueuing: $e');
      for (final l in lines) {
        await OfflineQueue.instance.enqueue(
          userId: userId,
          productName: l.productName,
          quantity: l.quantity,
        );
      }
      return AssistantReply(
        text: '目前無法連線，已離線暫存您的需求。\n網路恢復後會自動送出，請放心。',
        actions: const [_navShop],
      );
    }
  }

  Future<AssistantReply> _queryPrice(
    ShopIntentSlots? slots,
    String layerNote,
  ) async {
    final name = slots?.singleProduct?.trim() ?? '';
    if (name.isEmpty) {
      return AssistantReply(
        text: '想查哪一樣的價格呢？例如「雞蛋多少錢」。$layerNote',
        actions: const [_navPrices],
      );
    }
    final ref = await _priceRepo.findByName(name);
    if (ref == null) {
      return AssistantReply(
        text: '目前參考表裡還找不到「$name」的價格，'
            '您可以到全聯價格參考頁搜尋，或到柑仔店看目錄。$layerNote',
        actions: const [_navPrices, _navShop],
      );
    }
    final price = ref.unitPrice != null
        ? '約 ${ref.unitPrice!.toStringAsFixed(0)} 元'
        : '（價格待更新）';
    return AssistantReply(
      text: '「${ref.productName}」參考價 $price'
          '${ref.unitLabel != null ? '／${ref.unitLabel}' : ''}。\n'
          '實際以全聯門市為準喔。$layerNote',
      actions: const [_navPrices, _navShop],
    );
  }

  Future<AssistantReply> _viewRecorded(
    String userId,
    AssistantSnapshot snapshot,
    String layerNote,
  ) async {
    final buf = StringBuffer('您目前的記錄：\n');
    try {
      final draft = await _demandRepo.getOrCreateDraft(userId: userId);
      if (draft != null && draft.activeItems.isNotEmpty) {
        buf.writeln('【草稿需求】');
        for (final i in draft.activeItems) {
          buf.writeln('• ${i.productName} × ${i.quantity}');
        }
      } else {
        buf.writeln('【草稿需求】尚無項目。');
      }
    } catch (_) {
      buf.writeln('【草稿需求】暫時讀不到。');
    }

    if (snapshot.recentOrders.isNotEmpty) {
      buf.writeln('\n【已送出代購】');
      for (final o in snapshot.recentOrders.take(3)) {
        final st = ShopOrderStatus.orderStatusLabel(o.status);
        buf.writeln('• $st — ${o.items.map((e) => e.productName).join('、')}');
      }
    }

    buf.write(layerNote);
    return AssistantReply(
      text: buf.toString(),
      actions: const [_navShopOrders, _navShop],
    );
  }

  Future<AssistantReply> _cancelDemand(
    String userId,
    ShopIntentSlots? slots,
    String layerNote,
  ) async {
    final name = slots?.singleProduct?.trim() ?? '';
    if (name.isEmpty) {
      return AssistantReply(
        text: '要取消哪一項呢？例如「那個牛奶不要了」。$layerNote',
        actions: const [_navShopOrders],
      );
    }
    try {
      final updated = await _demandRepo.cancelProduct(
        userId: userId,
        productName: name,
      );
      final left = updated?.activeItems ?? const [];
      if (left.isEmpty) {
        return AssistantReply(
          text: '已將「$name」從草稿移除（或找不到該品項）。$layerNote',
          actions: const [_navShopOrders],
        );
      }
      return AssistantReply(
        text: '已處理取消「$name」。目前草稿還有：'
            '${left.map((i) => '${i.productName}×${i.quantity}').join('、')}。$layerNote',
        actions: const [_navShopOrders, _navShop],
      );
    } catch (e) {
      return AssistantReply(
        text: '取消時發生問題：$e$layerNote',
        actions: const [_navShopOrders],
      );
    }
  }
}

final demandRecordsRepositoryProvider =
    Provider<DemandRecordsRepository>((ref) => const DemandRecordsRepository());

final priceReferencesRepositoryProvider =
    Provider<PriceReferencesRepository>((ref) => const PriceReferencesRepository());

final assistantShopActionServiceProvider = Provider<AssistantShopActionService>(
  (ref) => AssistantShopActionService(
    demandRepo: ref.watch(demandRecordsRepositoryProvider),
    priceRepo: ref.watch(priceReferencesRepositoryProvider),
  ),
);
