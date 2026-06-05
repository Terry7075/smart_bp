import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/shop/data/clarification_session_repository.dart';
import 'package:smart_bp/features/shop/data/hybrid_nlu_orchestrator.dart';
import 'package:smart_bp/features/shop/data/personalized_recommendation_service.dart';
import 'package:smart_bp/features/shop/data/product_catalog.dart';
import 'package:smart_bp/features/shop/domain/recommendation_card.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';
import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';

/// 多輪追問：spec / 便宜 / 上次買的。
class ClarificationDialogueService {
  ClarificationDialogueService({
    HybridNluOrchestrator? nlu,
    ClarificationSessionRepository? sessions,
    PersonalizedRecommendationService? recommendations,
  })  : _nlu = nlu ?? HybridNluOrchestrator(),
        _sessions = sessions ?? ClarificationSessionRepository(),
        _recommendations =
            recommendations ?? PersonalizedRecommendationService();

  final HybridNluOrchestrator _nlu;
  final ClarificationSessionRepository _sessions;
  final PersonalizedRecommendationService _recommendations;

  Future<ClarificationTurnResult> handleUtterance({
    required String userId,
    required String utterance,
    String? sessionId,
    ShopNluResult? existingPartial,
    List<String>? existingMissing,
  }) async {
    var activeSessionId = sessionId;
    var partial = existingPartial;
    if ((activeSessionId == null || activeSessionId.isEmpty) &&
        partial == null) {
      final row = await _sessions.fetchOpenSession(userId);
      if (row != null) {
        activeSessionId = row['id']?.toString();
        partial = _sessions.partialFromRow(row);
      }
    }

    final nlu = await _nlu.parse(utterance, userId: userId);
    var merged = _mergePartial(partial, nlu, utterance);

    if (merged.wantsLastPurchase) {
      final last = await _recommendations.resolveLastPurchase(
        userId: userId,
        categoryKey: merged.categoryKey,
      );
      if (last != null) {
        merged = merged.copyWith(
          productItemId: last.productItemId,
          brandName: last.displayName,
          missingFields: [],
        );
      }
    }

    if (merged.pricePreference == 'budget' && merged.brandName == null) {
      final cards = await _recommendations.fetchCards(
        userId: userId,
        categoryKey: merged.categoryKey,
      );
      final budget = cards.budget;
      if (budget != null && budget.productItemId.isNotEmpty) {
        merged = merged.copyWith(
          productItemId: budget.productItemId,
          brandName: budget.displayName,
          missingFields: merged.missingFields.where((f) => f != 'brand').toList(),
        );
      }
    }

    final missing = ShopNluResult(
      confidence: merged.confidence,
      source: merged.source,
      categoryKey: merged.categoryKey,
      categoryLabel: merged.categoryLabel,
      brandName: merged.brandName,
      productItemId: merged.productItemId,
      spec: merged.spec,
      quantity: merged.quantity,
      missingFields: merged.missingFields,
      rawUtterance: utterance,
    ).missingFields;

    final resolveId = missing.isEmpty ? merged.productItemId : null;
    final sid = await _sessions.upsert(
      sessionId: activeSessionId,
      partialNlu: merged,
      missingFields: missing,
      utterance: utterance,
      resolveItemId: resolveId,
    );

    if (missing.isNotEmpty) {
      return ClarificationTurnResult(
        sessionId: sid,
        partial: merged,
        missingFields: missing,
        reply: _askFor(missing.first, merged),
        recommendationCards: await _cardsIfBrandMissing(userId, merged, missing),
      );
    }

    final snapshot = _toSnapshot(merged);
    return ClarificationTurnResult(
      sessionId: sid,
      partial: merged,
      missingFields: const [],
      snapshot: snapshot,
      reply: AssistantReply(
        text: '好的，已記下「${snapshot.productName}」${snapshot.quantity}${snapshot.unitLabel ?? "份"}。',
      ),
    );
  }

  Future<List<RecommendationCard>?> _cardsIfBrandMissing(
    String userId,
    ShopNluResult merged,
    List<String> missing,
  ) async {
    if (!missing.contains('brand')) return null;
    final cards = await _recommendations.fetchCards(
      userId: userId,
      categoryKey: merged.categoryKey,
      categoryId: merged.categoryId,
    );
    return cards.nonEmpty;
  }

  ShopNluResult _mergePartial(
    ShopNluResult? existing,
    ShopNluResult incoming,
    String utterance,
  ) {
    if (existing == null) return incoming.copyWith(rawUtterance: utterance);

    return ShopNluResult(
      confidence: incoming.confidence > existing.confidence
          ? incoming.confidence
          : existing.confidence,
      source: incoming.source,
      categoryKey: incoming.categoryKey ?? existing.categoryKey,
      categoryLabel: incoming.categoryLabel ?? existing.categoryLabel,
      categoryId: incoming.categoryId ?? existing.categoryId,
      brandName: incoming.brandName ?? existing.brandName,
      brandId: incoming.brandId ?? existing.brandId,
      productItemId: incoming.productItemId ?? existing.productItemId,
      spec: incoming.spec ?? existing.spec,
      quantity: incoming.quantity > 0 ? incoming.quantity : existing.quantity,
      unitLabel: incoming.unitLabel ?? existing.unitLabel,
      pricePreference: incoming.pricePreference ?? existing.pricePreference,
      wantsLastPurchase:
          incoming.wantsLastPurchase || existing.wantsLastPurchase,
      missingFields: incoming.missingFields.isNotEmpty
          ? incoming.missingFields
          : existing.missingFields,
      rawUtterance: utterance,
      matchLayer: incoming.matchLayer ?? existing.matchLayer,
    );
  }

  AssistantReply _askFor(String field, ShopNluResult partial) {
    final label = partial.categoryLabel ?? '這項商品';
    return switch (field) {
      'spec' => AssistantReply(
          text: '$label 要抽取式還是捲筒式？',
        ),
      'brand' => AssistantReply(
          text: '要哪個牌子呢？也可以選下面推薦卡片。',
        ),
      'category' => AssistantReply(
          text: '請再說一次要買什麼？例如衛生紙、雞蛋。',
        ),
      'last_purchase' => AssistantReply(
          text: '正在幫您找上次買的品項…',
        ),
      _ => AssistantReply(text: '請再補充一下需求細節。'),
    };
  }

  SupplyLineSnapshot _toSnapshot(ShopNluResult r) {
    final cat = r.categoryKey != null
        ? ProductCatalog.instance.categoryByKey(r.categoryKey!)
        : null;
    final brandLabel = r.brandName ?? '其他';
    final key = r.categoryKey ?? 'unknown';
    final productId = r.productItemId != null
        ? 'item:${r.productItemId}'
        : (r.brandId != null ? 'tpl:$key:${r.brandId}' : 'cat:$key');
    return SupplyLineSnapshot(
      productId: productId,
      productName: '${r.categoryLabel ?? cat?.label ?? "商品"} $brandLabel'
          .trim(),
      quantity: r.quantity,
      unitLabel: r.unitLabel ?? cat?.defaultUnitLabel,
      brand: brandLabel,
      spec: r.spec,
      category: r.categoryLabel ?? cat?.label,
      supplyCategoryKey: r.categoryKey,
      templateOptionId: null,
      categoryId: r.categoryId,
      brandId: r.brandId,
      productItemId: r.productItemId,
      normalizeConfidence: r.confidence,
    );
  }
}

final class ClarificationTurnResult {
  const ClarificationTurnResult({
    required this.sessionId,
    required this.partial,
    required this.missingFields,
    this.reply,
    this.snapshot,
    this.recommendationCards,
  });

  final String sessionId;
  final ShopNluResult partial;
  final List<String> missingFields;
  final AssistantReply? reply;
  final SupplyLineSnapshot? snapshot;
  final List<RecommendationCard>? recommendationCards;
}
