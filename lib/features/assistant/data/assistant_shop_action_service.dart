import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_navigation.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/shared/offline_queue/offline_queue.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/data/product_normalization_engine.dart';
import 'package:smart_bp/features/shop/data/supply_dialogue_service.dart';
import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';
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

  static const _navShop = AssistantShopNavigation.browse;
  static const _navShopSubmit = AssistantShopNavigation.submit;
  static const _navShopOrders = AssistantShopNavigation.orders;
  static AssistantNavAction _navPrices([String? searchQuery]) {
    final q = searchQuery?.trim();
    if (q == null || q.isEmpty) {
      return const AssistantNavAction(label: '常用品參考價', route: '/shop/prices');
    }
    return AssistantNavAction(
      label: '常用品參考價',
      route: '/shop/prices',
      queryParameters: {'q': q},
    );
  }

  Future<AssistantReply> handle({
    required ShopIntentClassification classification,
    required String userId,
    required AssistantSnapshot snapshot,
  }) async {
    final intent = classification.intent;
    final slots = classification.slots;
    if (kDebugMode) {
      debugPrint(
        '[AssistantShop] ${classification.intentLabel} '
        '${classification.layer} ${classification.elapsedMs}ms',
      );
    }

    switch (intent) {
      case AssistantShopIntent.recordDemand:
        return _recordDemand(userId, slots);
      case AssistantShopIntent.shortageSuggest:
        return _shortageSuggest(slots);
      case AssistantShopIntent.queryPrice:
        return _queryPrice(slots);
      case AssistantShopIntent.viewRecorded:
        return _viewRecorded(userId, snapshot);
      case AssistantShopIntent.cancelDemand:
        return _cancelDemand(userId, slots);
      case AssistantShopIntent.queryOrderStatus:
        return _queryOrderStatus(snapshot);
      case AssistantShopIntent.casual:
        return AssistantReply(
          text: '您好！想記需求可以說「我要買米和醬油」，'
              '或跟我說「我家衛生紙沒了」，我會問您要不要代購。',
          actions: [_navShop, _navPrices()],
        );
    }
  }

  AssistantReply _shortageSuggest(ShopIntentSlots? slots) {
    final name = slots?.singleProduct?.trim() ?? '';
    if (name.isEmpty) {
      return const AssistantReply(
        text: '哪一樣東西用完了呢？例如說「我家衛生紙沒了」。',
        actions: [_navShop],
      );
    }
    return AssistantReply(
      text: '聽起來家裡的「$name」用完了。\n需要幫您記下來，請志工代購嗎？',
      actions: [
        AssistantNavAction(
          label: '好，幫我買',
          sendMessageOnTap: '好，幫我買$name',
        ),
        AssistantNavAction(
          label: '先查價格',
          sendMessageOnTap: '$name多少錢',
        ),
        _navPrices(name),
        _navShop,
      ],
    );
  }

  Future<AssistantReply> _recordDemand(
    String userId,
    ShopIntentSlots? slots,
  ) async {
    final lines = slots?.lines ?? const [];
    final supplyDialogue = SupplyDialogueService();
    final pne = ProductNormalizationEngine();
    if (lines.length == 1) {
      final pending = supplyDialogue.pendingFromDemandLine(
        lines.first.productName,
        lines.first.quantity,
      );
      if (pending != null) {
        return supplyDialogue.brandAskReplyFor(pending);
      }
    }
    if (lines.isEmpty) {
      return const AssistantReply(
        text: '想買什麼可以跟我說，例如「我要買兩瓶醬油」。',
        actions: [_navShop],
      );
    }
    try {
      final snapshots = <SupplyLineSnapshot>[];
      final legacy = <({String productName, int quantity, String? productId, double? unitPrice})>[];
      for (final l in lines) {
        final utterance = '${l.productName} ${l.quantity}';
        final canonical = pne.normalize(utterance);
        if (canonical.needsBrandClarification) {
          final pending = supplyDialogue.pendingFromDemandLine(
            l.productName,
            l.quantity,
          );
          if (pending != null) {
            return supplyDialogue.brandAskReplyFor(pending);
          }
        }
        final fromPne = pne.toSnapshot(canonical);
        if (fromPne != null && canonical.hasBrand) {
          snapshots.add(fromPne);
          continue;
        }
        final cat = ElderSupplyTemplates.findCategoryByKeyword(l.productName);
        final opt = cat != null
            ? ElderSupplyTemplates.findOption(cat, l.productName)
            : null;
        if (cat != null && opt != null && !opt.isOther) {
          snapshots.add(
            ElderSupplyTemplates.buildSnapshot(
              category: cat,
              option: opt,
              quantity: l.quantity,
            ),
          );
        } else {
          legacy.add((
            productName: l.productName,
            quantity: l.quantity,
            productId: null as String?,
            unitPrice: null as double?,
          ));
        }
      }
      DemandRecord record;
      if (snapshots.isNotEmpty) {
        record = await _demandRepo.addSnapshotLinesResilient(
          userId: userId,
          lines: snapshots,
        );
      } else {
        record = await _demandRepo.getOrCreateDraft(userId: userId) ??
            (throw const AuthException('無法建立採買清單'));
      }
      if (legacy.isNotEmpty) {
        record = await _demandRepo.addLines(userId: userId, lines: legacy);
      }
      final summary = record.activeItems
          .map((i) => '${i.productName}×${i.quantity}')
          .join('、');
      return AssistantReply(
        text: '好，已幫您記在採買清單裡：$summary。\n'
            '請到柑仔店按「送出給志工」，或跟我說「我剛剛說要買什麼」查看。',
        actions: const [_navShopSubmit, _navShopOrders],
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
        text: '目前無法連線，已離線暫存您的需求。\n連線恢復後會寫入採買清單，請到柑仔店按「送出給志工」。',
        actions: const [_navShop],
      );
    }
  }

  Future<AssistantReply> _queryPrice(
    ShopIntentSlots? slots,
  ) async {
    final name = slots?.singleProduct?.trim() ?? '';
    if (name.isEmpty) {
      return AssistantReply(
        text: '想查哪一樣的價格呢？例如「雞蛋多少錢」。',
        actions: [_navPrices()],
      );
    }
    final ref = await _priceRepo.findByName(name);
    if (ref == null) {
      return AssistantReply(
        text: '目前參考表裡還找不到「$name」的價格，'
            '您可以到常用品參考價頁搜尋，或到柑仔店看目錄。',
        actions: [_navPrices(name), _navShop],
      );
    }
    final price = ref.unitPrice != null
        ? '約 ${ref.unitPrice!.toStringAsFixed(0)} 元'
        : '（價格待更新）';
    return AssistantReply(
      text: '「${ref.productName}」參考價 $price'
          '${ref.unitLabel != null ? '／${ref.unitLabel}' : ''}。\n'
          '實際以全聯門市為準喔。',
      actions: [_navPrices(ref.productName), _navShop],
    );
  }

  Future<AssistantReply> _viewRecorded(
    String userId,
    AssistantSnapshot snapshot,
  ) async {
    final buf = StringBuffer('您目前的記錄：\n');
    try {
      final draft = await _demandRepo.getOrCreateDraft(userId: userId);
      if (draft != null && draft.activeItems.isNotEmpty) {
        buf.writeln('【採買清單】');
        for (final i in draft.activeItems) {
          buf.writeln('• ${i.productName} × ${i.quantity}');
        }
      } else {
        buf.writeln('【採買清單】尚無項目。');
      }
    } catch (_) {
      buf.writeln('【採買清單】暫時讀不到。');
    }

    if (snapshot.recentOrders.isNotEmpty) {
      buf.writeln('\n【已送出代購】');
      for (final o in snapshot.recentOrders.take(3)) {
        final st = ShopOrderStatus.orderStatusLabel(o.status);
        buf.writeln('• $st — ${o.items.map((e) => e.productName).join('、')}');
      }
    }

    return AssistantReply(
      text: buf.toString(),
      actions: const [_navShopOrders, _navShop],
    );
  }

  Future<AssistantReply> _cancelDemand(
    String userId,
    ShopIntentSlots? slots,
  ) async {
    final name = slots?.singleProduct?.trim() ?? '';
    if (name.isEmpty) {
      return const AssistantReply(
        text: '要取消哪一項呢？例如「那個牛奶不要了」。',
        actions: [_navShopOrders],
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
          text: '已將「$name」從採買清單移除（或找不到該品項）。',
          actions: const [_navShopOrders],
        );
      }
      return AssistantReply(
        text: '已處理取消「$name」。目前採買清單還有：'
            '${left.map((i) => '${i.productName}×${i.quantity}').join('、')}。',
        actions: const [_navShopOrders, _navShop],
      );
    } catch (e) {
      return AssistantReply(
        text: '取消時發生問題：$e',
        actions: const [_navShopOrders],
      );
    }
  }

  /// 查詢最近 1～3 筆訂單狀態，用長者聽得懂的語句回覆（搭配 TTS 播報）。
  Future<AssistantReply> _queryOrderStatus(
    AssistantSnapshot snapshot,
  ) async {
    final orders = snapshot.recentOrders.take(3).toList();
    if (orders.isEmpty) {
      return const AssistantReply(
        text: '目前查不到您有送出的需求單。\n'
            '若要下單可以說「我要買衛生紙」，或「我家衛生紙沒了」。',
        actions: [_navShop],
      );
    }
    final buf = StringBuffer('您最近的需求單：\n');
    for (final o in orders) {
      final label = ShopOrderStatus.orderStatusLabel(o.status);
      final items = o.items.map((i) => i.productName).join('、');
      buf.writeln('• $items — $label');
    }
    return AssistantReply(
      text: buf.toString(),
      actions: const [_navShopOrders],
    );
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
