import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/shop/data/product_normalization_engine.dart';
import 'package:smart_bp/features/shop/data/shop_nlu_validator.dart';
import 'package:smart_bp/features/shop/domain/canonical_product.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

/// Hybrid NLU：規則優先，confidence &lt; 0.75 時呼叫 Edge `parse_shop_nlu`。
class HybridNluOrchestrator {
  HybridNluOrchestrator({
    ProductNormalizationEngine? pne,
    SupabaseClient? client,
    bool useSupabaseWhenNull = true,
  })  : _pne = pne ?? ProductNormalizationEngine(),
        _client = client ??
            (useSupabaseWhenNull ? Supabase.instance.client : null);

  final ProductNormalizationEngine _pne;
  final SupabaseClient? _client;

  static const edgeThreshold = ShopNluValidator.confidenceThreshold;

  Future<ShopNluResult> parse(String utterance, {String? userId}) async {
    final trimmed = utterance.trim();
    if (trimmed.isEmpty) {
      return const ShopNluResult(
        confidence: 0,
        source: 'rule',
        intent: 'casual',
        missingFields: ['utterance'],
      );
    }

    final rule = _parseWithRules(trimmed);
    if (rule.confidence >= edgeThreshold) {
      return ShopNluValidator.validate(rule);
    }

    try {
      final edge = await _parseWithEdge(trimmed, userId: userId);
      if (edge != null && edge.confidence > rule.confidence) {
        return ShopNluValidator.validate(edge);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('HybridNluOrchestrator edge fallback: $e\n$st');
      }
    }

    return ShopNluValidator.validate(rule);
  }

  ShopNluResult _parseWithRules(String utterance) {
    final n = utterance.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final wantsLast = n.contains('上次買') ||
        n.contains('上次那個') ||
        n.contains('跟上次一樣');
    final wantsCheap = n.contains('便宜') ||
        n.contains('划算') ||
        n.contains('省一點');

    final classification = AssistantShopIntentClassifier.classify(utterance);
    final canonical = _pne.normalize(utterance);
    final fromCanonical = _fromCanonical(canonical, utterance);

    if (wantsLast) {
      return fromCanonical.copyWith(
        wantsLastPurchase: true,
        missingFields: ['last_purchase'],
        source: 'rule',
      );
    }

    if (wantsCheap && fromCanonical.brandName == null) {
      return fromCanonical.copyWith(
        pricePreference: 'budget',
        source: 'rule',
      );
    }

    if (classification.intent == AssistantShopIntent.recordDemand) {
      return fromCanonical.copyWith(
        intent: 'record_demand',
        source: 'rule_${classification.layer}',
      );
    }

    return fromCanonical.copyWith(
      intent: switch (classification.intent) {
        AssistantShopIntent.queryPrice => 'query_price',
        AssistantShopIntent.queryOrderStatus => 'query_status',
        AssistantShopIntent.cancelDemand => 'cancel',
        AssistantShopIntent.viewRecorded => 'view_recorded',
        _ => 'casual',
      },
      source: 'rule_${classification.layer}',
    );
  }

  ShopNluResult _fromCanonical(CanonicalProduct c, String utterance) {
    final missing = <String>[];
    if (c.categoryKey == 'unknown') missing.add('category');
    if (c.brand == null && c.brandId == null) missing.add('brand');
    if ((c.categoryKey == 'tissue' || c.categoryKey == 'detergent') &&
        c.spec == null) {
      missing.add('spec');
    }

    return ShopNluResult(
      confidence: c.confidence,
      source: 'rule',
      categoryKey: c.categoryKey,
      categoryLabel: c.category,
      categoryId: _uuidOrNull(c.categoryId),
      brandName: c.brand,
      brandId: _uuidOrNull(c.brandId),
      spec: c.spec,
      quantity: c.quantity,
      unitLabel: c.unitLabel,
      missingFields: missing,
      rawUtterance: utterance,
      matchLayer: c.matchLayer,
    );
  }

  static String? _uuidOrNull(String? id) {
    if (id == null || id.isEmpty) return null;
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return re.hasMatch(id) ? id : null;
  }

  Future<ShopNluResult?> _parseWithEdge(String utterance, {String? userId}) async {
    final client = _client;
    if (client == null) return null;
    final res = await client.functions.invoke(
      'parse_shop_nlu',
      body: {
        'utterance': utterance,
        'locale': 'zh-TW',
        if (userId != null) 'user_id': userId,
      },
    );
    if (res.status != 200) return null;
    final data = res.data;
    if (data is! Map) return null;
    final inner = data['result'] ?? data['data'] ?? data;
    if (inner is! Map) return null;
    return ShopNluResult.fromJson(Map<String, dynamic>.from(inner as Map));
  }
}
