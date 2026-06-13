import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/shop/data/hybrid_nlu_orchestrator.dart';
import 'package:smart_bp/features/shop/data/product_item_resolver.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';

/// 柑仔店／需求輸入：Hybrid NLU + DB SKU 解析 → 小幫手動作層。
class ShopUtteranceHandler {
  ShopUtteranceHandler({
    HybridNluOrchestrator? nlu,
    ProductItemResolver? resolver,
    required AssistantShopActionService actionService,
  })  : _nlu = nlu ?? HybridNluOrchestrator(),
        _resolver = resolver ?? ProductItemResolver(),
        _actionService = actionService;

  final HybridNluOrchestrator _nlu;
  final ProductItemResolver _resolver;
  final AssistantShopActionService _actionService;

  Future<AssistantReply> handle({
    required String userId,
    required String utterance,
  }) async {
    final parsed = await _nlu.parse(utterance, userId: userId);
    final enriched = await _resolver.enrich(parsed);
    final classification = classificationFromNlu(enriched, utterance);
    return _actionService.handle(
      classification: classification,
      userId: userId,
      snapshot: const AssistantSnapshot(),
    );
  }

  static ShopIntentClassification classificationFromNlu(
    ShopNluResult result,
    String utterance,
  ) {
    final intent = switch (result.intent) {
      'record_demand' => AssistantShopIntent.recordDemand,
      'query_price' => AssistantShopIntent.queryPrice,
      'query_status' => AssistantShopIntent.queryOrderStatus,
      'cancel' => AssistantShopIntent.cancelDemand,
      'view_recorded' => AssistantShopIntent.viewRecorded,
      _ => _inferIntent(utterance),
    };

    final layer = result.matchLayer ?? result.source;
    ShopIntentSlots? slots;

    if (intent == AssistantShopIntent.recordDemand) {
      final name = _lineLabel(result, utterance);
      slots = ShopIntentSlots(
        lines: [DemandLineSlot(productName: name, quantity: result.quantity)],
      );
    } else if (intent == AssistantShopIntent.queryPrice ||
        intent == AssistantShopIntent.cancelDemand) {
      slots = ShopIntentSlots(
        singleProduct: result.brandName ??
            result.categoryLabel ??
            utterance.replaceAll(RegExp(r'多少錢|價格|不要了|取消'), '').trim(),
      );
    } else if (intent == AssistantShopIntent.shortageSuggest) {
      slots = ShopIntentSlots(
        singleProduct: result.categoryLabel ?? utterance,
      );
    }

    return ShopIntentClassification(
      intent: intent,
      layer: layer,
      slots: slots,
      elapsedMs: 0,
    );
  }

  static AssistantShopIntent _inferIntent(String utterance) {
    final n = utterance.replaceAll(RegExp(r'\s+'), '');
    if (n.contains('沒了') || n.contains('用完了')) {
      return AssistantShopIntent.shortageSuggest;
    }
    return AssistantShopIntent.casual;
  }

  static String _lineLabel(ShopNluResult result, String fallback) {
    if (result.brandName != null && result.brandName!.isNotEmpty) {
      return result.brandName!;
    }
    if (result.categoryLabel != null && result.categoryLabel!.isNotEmpty) {
      return result.categoryLabel!;
    }
    return fallback.trim();
  }
}

final shopUtteranceHandlerProvider = Provider<ShopUtteranceHandler>((ref) {
  return ShopUtteranceHandler(
    nlu: ref.watch(hybridNluOrchestratorProvider),
    actionService: ref.watch(assistantShopActionServiceProvider),
  );
});
