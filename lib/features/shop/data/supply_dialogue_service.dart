import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/data/product_normalization_engine.dart';
import 'package:smart_bp/features/shop/data/recommendation_engine.dart';
import 'package:smart_bp/features/shop/data/shop_quantity_parser.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';

/// 多輪代購對話（品類 → 品牌 → 寫入快照）。
class SupplyDialogueService {
  SupplyDialogueService({
    ProductNormalizationEngine? normalizationEngine,
    RecommendationEngine? recommendationEngine,
  })  : _normalization = normalizationEngine ?? ProductNormalizationEngine(),
        _recommendation = recommendationEngine ?? RecommendationEngine();

  final ProductNormalizationEngine _normalization;
  final RecommendationEngine _recommendation;

  /// 從「我要衛生紙兩包」等語句啟動品牌追問。
  PendingSupplyDialogue? tryStartFromUtterance(String raw) {
    final parsed = ShopQuantityParser.parseCategoryRequest(raw);
    if (parsed == null) return null;
    final cat = ElderSupplyTemplates.findCategoryByKeyword(parsed.categoryKeyword);
    if (cat == null) return null;
    if (!ElderSupplyTemplates.isBareCategoryLine(parsed.categoryKeyword)) {
      return null;
    }
    return PendingSupplyDialogue(
      categoryKey: cat.key,
      categoryLabel: cat.label,
      quantity: parsed.quantity,
      unitLabel: parsed.unitLabel ?? cat.defaultUnitLabel,
      rawUtterance: raw,
      categoryImageUrl: cat.categoryImageUrl,
    );
  }

  /// 處理 pending 狀態下的一句回覆。
  ({PendingSupplyDialogue? next, AssistantReply? reply, SupplyLineSnapshot? snapshot})
      handlePending({
    required PendingSupplyDialogue pending,
    required String userText,
  }) {
    final cat = ElderSupplyTemplates.findCategoryByKey(pending.categoryKey);
    if (cat == null) {
      return (next: null, reply: null, snapshot: null);
    }

    switch (pending.step) {
      case SupplyDialogueStep.awaitBrand:
        final option = ElderSupplyTemplates.findOption(cat, userText);
        if (option == null) {
          return (
            next: pending,
            reply: _brandAskReply(cat, pending),
            snapshot: null,
          );
        }
        if (option.isOther) {
          return (
            next: pending.copyWith(
              step: SupplyDialogueStep.awaitOtherNote,
              selectedOptionId: option.id,
            ),
            reply: AssistantReply(
              text: '好的，請告訴我您想要哪一款${cat.label}（或說「都可以」）。',
              actions: const [],
            ),
            snapshot: null,
          );
        }
        final snap = ElderSupplyTemplates.buildSnapshot(
          category: cat,
          option: option,
          quantity: pending.quantity,
          unitLabel: pending.unitLabel,
        );
        final brandLine = option.isUnspecified
            ? '${cat.label}（志工代選品牌）'
            : '${snap.brand} · ${snap.productName}';
        return (
          next: null,
          reply: AssistantReply(
            text: '已加入採買清單：$brandLine × ${snap.quantity}${snap.unitLabel ?? ""}。\n'
                '確認無誤後，請按下方「送出給志工」。',
            actions: const [],
          ),
          snapshot: snap,
        );
      case SupplyDialogueStep.awaitOtherNote:
        final option = cat.options.firstWhere((o) => o.isOther);
        final note = userText.trim().isEmpty ? pending.rawUtterance : userText.trim();
        final snap = ElderSupplyTemplates.buildSnapshot(
          category: cat,
          option: option,
          quantity: pending.quantity,
          unitLabel: pending.unitLabel,
          referenceNote: note ?? cat.label,
        );
        return (
          next: null,
          reply: AssistantReply(
            text: '已記下：${cat.label}（其他）× ${snap.quantity}，備註：${snap.referenceNote}。\n'
                '確認無誤後，請按下方「送出給志工」。',
            actions: const [],
          ),
          snapshot: snap,
        );
      case SupplyDialogueStep.awaitQty:
        return (next: null, reply: null, snapshot: null);
    }
  }

  AssistantReply brandAskReplyFor(PendingSupplyDialogue pending) {
    final cat = ElderSupplyTemplates.findCategoryByKey(pending.categoryKey);
    if (cat == null) {
      return const AssistantReply(text: '請再說一次想買的東西。');
    }
    return _brandAskReply(cat, pending);
  }

  AssistantReply _brandAskReply(SupplyCategory cat, PendingSupplyDialogue pending) {
    final qty = pending.quantity;
    final unit = pending.unitLabel ?? cat.defaultUnitLabel;
    final ranked = _recommendation.recommendLocal(categoryKey: cat.key, limit: 5);
    final rankIds = ranked.map((r) => r.templateOptionId ?? r.brandId).toSet();
    final sortedOptions = [...cat.options]
      ..sort((a, b) {
        int tier(SupplyBrandOption o) {
          if (o.isOther) return 2;
          if (o.isUnspecified) return 1;
          return 0;
        }
        final ta = tier(a);
        final tb = tier(b);
        if (ta != tb) return ta.compareTo(tb);
        final ai = rankIds.contains(a.id)
            ? ranked.indexWhere(
                (r) => r.templateOptionId == a.id || r.brandId == a.id,
              )
            : 99;
        final bi = rankIds.contains(b.id)
            ? ranked.indexWhere(
                (r) => r.templateOptionId == b.id || r.brandId == b.id,
              )
            : 99;
        return ai.compareTo(bi);
      });
    final choices = <AssistantBrandChoice>[];
    final actions = <AssistantNavAction>[];
    for (var i = 0; i < sortedOptions.length; i++) {
      final o = sortedOptions[i];
      final idx = i + 1;
      final price = o.refPrice != null ? '約\${o.refPrice!.toInt()}元' : null;
      choices.add(
        AssistantBrandChoice(
          index: idx,
          optionId: o.id,
          label: o.brand,
          subtitle: o.spec,
          priceHint: price,
          imageUrl: o.imageUrl,
          sendMessageOnTap: '$idx',
        ),
      );
      actions.add(
        AssistantNavAction(
          label: '$idx. ${o.brand}',
          sendMessageOnTap: '$idx',
        ),
      );
    }
    final hint = ranked.isNotEmpty
        ? '\n（依社區常買與參考價推薦：${ranked.take(3).map((r) => r.brandName).join('、')}）'
        : '';
    return AssistantReply(
      text: '您要${cat.label} $qty $unit。\n請問要哪一款？點選下方或說 1、2、3。$hint',
      actions: actions,
      brandChoices: choices,
      categoryImageUrl: pending.categoryImageUrl ?? cat.categoryImageUrl,
    );
  }

  /// recordDemand 槽位若只有類別名，改為啟動 pending 而非直接寫入。
  PendingSupplyDialogue? pendingFromDemandLine(String productName, int quantity) {
    final canonical = _normalization.normalize(productName);
    if (canonical.needsBrandClarification || !canonical.hasBrand) {
      final cat = ElderSupplyTemplates.findCategoryByKey(canonical.categoryKey) ??
          ElderSupplyTemplates.findCategoryByKeyword(productName);
      if (cat == null) return null;
      return PendingSupplyDialogue(
        categoryKey: cat.key,
        categoryLabel: cat.label,
        quantity: canonical.quantity,
        unitLabel: canonical.unitLabel ?? cat.defaultUnitLabel,
        rawUtterance: productName,
        categoryImageUrl: cat.categoryImageUrl,
      );
    }
    if (!ElderSupplyTemplates.isBareCategoryLine(productName)) return null;
    final cat = ElderSupplyTemplates.findCategoryByKeyword(productName);
    if (cat == null) return null;
    return PendingSupplyDialogue(
      categoryKey: cat.key,
      categoryLabel: cat.label,
      quantity: quantity,
      unitLabel: cat.defaultUnitLabel,
      rawUtterance: productName,
      categoryImageUrl: cat.categoryImageUrl,
    );
  }
}
