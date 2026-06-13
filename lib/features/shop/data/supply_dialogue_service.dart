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
        final brandOpt = ElderSupplyTemplates.findBrandOption(cat, userText);
        if (brandOpt == null) {
          return (
            next: pending,
            reply: _brandAskReply(cat, pending),
            snapshot: null,
          );
        }
        if (brandOpt.isOther) {
          return (
            next: pending.copyWith(
              step: SupplyDialogueStep.awaitOtherNote,
              selectedOptionId: brandOpt.id,
            ),
            reply: AssistantReply(
              text: '請說出想要的品牌名稱。',
              actions: const [],
            ),
            snapshot: null,
          );
        }
        return (
          next: pending.copyWith(
            step: SupplyDialogueStep.awaitCapacity,
            selectedBrand: brandOpt.brand,
          ),
          reply: _capacityAskReply(cat, pending, brandOpt.brand),
          snapshot: null,
        );
      case SupplyDialogueStep.awaitCapacity:
        final brand = pending.selectedBrand;
        if (brand == null || brand.isEmpty) {
          return (next: null, reply: null, snapshot: null);
        }
        final capOpt = ElderSupplyTemplates.findCapacityOption(cat, brand, userText);
        if (capOpt == null) {
          return (
            next: pending,
            reply: _capacityAskReply(cat, pending, brand),
            snapshot: null,
          );
        }
        if (capOpt.isCustomCapacity) {
          final t = userText.trim();
          if (!RegExp(r'^\d+$').hasMatch(t) && t.isNotEmpty) {
            final snap = ElderSupplyTemplates.buildSnapshot(
              category: cat,
              option: capOpt,
              quantity: pending.quantity,
              unitLabel: pending.unitLabel,
              specOverride: t,
            );
            return (
              next: null,
              reply: _addedReply(cat, snap),
              snapshot: snap,
            );
          }
          return (
            next: pending.copyWith(step: SupplyDialogueStep.awaitCustomCapacity),
            reply: AssistantReply(
              text: brand == ElderSupplyTemplates.unspecifiedBrandLabel
                  ? '請說出想要的容量，品牌由志工代選。'
                  : '請說出想要的容量。',
              actions: const [],
            ),
            snapshot: null,
          );
        }
        final snap = ElderSupplyTemplates.buildSnapshot(
          category: cat,
          option: capOpt,
          quantity: pending.quantity,
          unitLabel: pending.unitLabel,
        );
        return (
          next: null,
          reply: _addedReply(cat, snap),
          snapshot: snap,
        );
      case SupplyDialogueStep.awaitCustomCapacity:
        final brand = pending.selectedBrand;
        if (brand == null || brand.isEmpty) {
          return (next: null, reply: null, snapshot: null);
        }
        final spec = userText.trim();
        if (spec.isEmpty) {
          return (
            next: pending,
            reply: AssistantReply(
              text: '請再說一次容量。',
              actions: const [],
            ),
            snapshot: null,
          );
        }
        final snap = ElderSupplyTemplates.buildSnapshot(
          category: cat,
          option: ElderSupplyTemplates.customCapacityPicker(cat, brand),
          quantity: pending.quantity,
          unitLabel: pending.unitLabel,
          specOverride: spec,
        );
        return (
          next: null,
          reply: _addedReply(cat, snap),
          snapshot: snap,
        );
      case SupplyDialogueStep.awaitOtherNote:
        final note = userText.trim();
        if (note.isEmpty) {
          return (
            next: pending,
            reply: const AssistantReply(
              text: '請說出想要的品牌名稱。',
              actions: [],
            ),
            snapshot: null,
          );
        }
        return (
          next: pending.copyWith(
            step: SupplyDialogueStep.awaitCapacity,
            selectedBrand: note,
          ),
          reply: _capacityAskReply(
            cat,
            pending.copyWith(selectedBrand: note),
            note,
          ),
          snapshot: null,
        );
      case SupplyDialogueStep.awaitQty:
        return (next: null, reply: null, snapshot: null);
    }
  }

  AssistantReply _addedReply(SupplyCategory cat, SupplyLineSnapshot snap) {
    final brandLine = snap.brand == ElderSupplyTemplates.unspecifiedBrandLabel
        ? '${cat.label}（${ElderSupplyTemplates.volunteerPickBrandDisplayLabel}）${snap.spec ?? ""}'
        : '${ElderSupplyTemplates.displayBrandLabel(snap.brand)} · ${snap.productName} ${snap.spec ?? ""}';
    return AssistantReply(
      text: '已加入採買清單：$brandLine × ${snap.quantity}${snap.unitLabel ?? ""}。',
      actions: const [],
    );
  }

  AssistantReply _capacityAskReply(
    SupplyCategory cat,
    PendingSupplyDialogue pending,
    String brand,
  ) {
    final qty = pending.quantity;
    final unit = pending.unitLabel ?? cat.defaultUnitLabel;
    final choices = ElderSupplyTemplates.capacityChoicesForBrand(cat, brand);
    final actions = <AssistantNavAction>[];
    final brandChoices = <AssistantBrandChoice>[];
    for (var i = 0; i < choices.length; i++) {
      final o = choices[i];
      final idx = i + 1;
      final label = o.isCustomCapacity ? '自己填容量' : o.spec;
      brandChoices.add(
        AssistantBrandChoice(
          index: idx,
          optionId: o.id,
          label: label,
          priceHint: o.isCustomCapacity
              ? '自行輸入'
              : o.refPrice != null
                  ? '約 ${o.refPrice!.toInt()} 元'
                  : '請志工現場確認',
          fallbackEmoji: ElderSupplyTemplates.emojiForCategoryKey(cat.key),
          sendMessageOnTap: '$idx',
        ),
      );
      actions.add(
        AssistantNavAction(
          label: '$idx. $label',
          sendMessageOnTap: '$idx',
        ),
      );
    }
    final brandHint = brand == ElderSupplyTemplates.unspecifiedBrandLabel
        ? '（${ElderSupplyTemplates.volunteerPickBrandDisplayLabel}）'
        : '（${ElderSupplyTemplates.displayBrandLabel(brand)}）';
    return AssistantReply(
      text: '您要${cat.label} $qty $unit $brandHint。\n請問要哪個容量？',
      actions: actions,
      brandChoices: brandChoices,
      categoryImageUrl: pending.categoryImageUrl ?? cat.categoryImageUrl,
    );
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
    final sortedOptions = ElderSupplyTemplates.distinctBrands(cat)
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
      choices.add(
        AssistantBrandChoice(
          index: idx,
          optionId: o.id,
          label: ElderSupplyTemplates.displayBrandLabel(o.brand),
          subtitle: o.isUnspecified
              ? '由志工依現場狀況代選'
              : (o.isOther ? '請填寫指定品牌' : null),
          fallbackEmoji: ElderSupplyTemplates.emojiForCategoryKey(cat.key),
          sendMessageOnTap: '$idx',
        ),
      );
      actions.add(
        AssistantNavAction(
          label: '$idx. ${ElderSupplyTemplates.displayBrandLabel(o.brand)}',
          sendMessageOnTap: '$idx',
        ),
      );
    }
    return AssistantReply(
      text: '您要${cat.label} $qty $unit。\n請問要哪一款？',
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
