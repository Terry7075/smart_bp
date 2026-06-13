import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/data/product_catalog.dart';
import 'package:smart_bp/features/shop/data/recommendation_engine.dart';
import 'package:smart_bp/features/shop/domain/recommendation_card.dart';

/// 三卡個人化推薦（常買 / 便宜 / 志工）。
class PersonalizedRecommendationService {
  PersonalizedRecommendationService({
    SupabaseClient? client,
    RecommendationEngine? engine,
  })  : _client = client ?? Supabase.instance.client,
        _engine = engine ?? RecommendationEngine();

  final SupabaseClient _client;
  final RecommendationEngine _engine;

  Future<RecommendationCardSet> fetchCards({
    required String userId,
    String? categoryKey,
    String? categoryId,
    String? locationPointId,
  }) async {
    try {
      final raw = await _client.rpc(
        'get_recommendation_cards',
        params: {
          'p_user_id': userId,
          'p_category_id': categoryId,
          'p_category_key': categoryKey,
          'p_location_point_id': locationPointId,
        },
      );
      if (raw is Map) {
        return RecommendationCardSet(
          frequent: RecommendationCard.fromRpcEntry(
            RecommendationCardKind.frequent,
            raw['frequent'] is Map
                ? Map<String, dynamic>.from(raw['frequent'] as Map)
                : null,
          ),
          budget: RecommendationCard.fromRpcEntry(
            RecommendationCardKind.budget,
            raw['budget'] is Map
                ? Map<String, dynamic>.from(raw['budget'] as Map)
                : null,
          ),
          volunteerPick: RecommendationCard.fromRpcEntry(
            RecommendationCardKind.volunteerPick,
            raw['volunteer_pick'] is Map
                ? Map<String, dynamic>.from(raw['volunteer_pick'] as Map)
                : null,
          ),
        );
      }
    } catch (_) {
      // fallback local
    }
    if (categoryKey != null) return _localCards(categoryKey);
    return _defaultDemoCards();
  }

  /// 無分類篩選時的預設三卡（口試 Demo 必備示意圖）。
  RecommendationCardSet _defaultDemoCards() {
    final keys = ['tissue', 'milk', 'egg'];
    final kinds = [
      RecommendationCardKind.frequent,
      RecommendationCardKind.budget,
      RecommendationCardKind.volunteerPick,
    ];
    RecommendationCard? pick(String key, RecommendationCardKind kind) {
      final cat = ElderSupplyTemplates.findCategoryByKey(key);
      if (cat == null) return null;
      final opt = cat.options.firstWhere(
        (o) => !o.isOther && !o.isUnspecified,
        orElse: () => cat.options.first,
      );
      return RecommendationCard(
        kind: kind,
        productItemId: opt.templateProductId,
        displayName: opt.displayName,
        reason: switch (kind) {
          RecommendationCardKind.frequent => '熱門選項',
          RecommendationCardKind.budget => '價格較親民',
          RecommendationCardKind.volunteerPick => '志工常推薦',
        },
        refPrice: opt.refPrice,
        templateOptionId: opt.id,
        imageUrl: opt.imageUrl,
      );
    }

    return RecommendationCardSet(
      frequent: pick(keys[0], kinds[0]),
      budget: pick(keys[1], kinds[1]),
      volunteerPick: pick(keys[2], kinds[2]),
    );
  }

  RecommendationCardSet _localCards(String? categoryKey) {
    if (categoryKey == null) return const RecommendationCardSet();
    final brands = _engine.recommendLocal(categoryKey: categoryKey, limit: 3);
    if (brands.isEmpty) return const RecommendationCardSet();

    RecommendationCard card(BrandRecommendation b, RecommendationCardKind k) {
      final opt = ElderSupplyTemplates.findOptionByTemplateId(b.templateOptionId);
      return RecommendationCard(
        kind: k,
        productItemId: b.brandId,
        displayName: b.displayName,
        reason: switch (k) {
          RecommendationCardKind.frequent => '熱門選項',
          RecommendationCardKind.budget => '價格較親民',
          RecommendationCardKind.volunteerPick => '志工常推薦',
        },
        refPrice: b.refPrice,
        brandId: b.brandId,
        templateOptionId: b.templateOptionId,
        imageUrl: opt?.imageUrl,
      );
    }

    final sorted = [...brands]..sort((a, b) => b.score.compareTo(a.score));
    final byPrice = [...brands]
      ..sort((a, b) => (a.refPrice ?? 999).compareTo(b.refPrice ?? 999));

    return RecommendationCardSet(
      frequent: card(sorted.first, RecommendationCardKind.frequent),
      budget: card(byPrice.first, RecommendationCardKind.budget),
      volunteerPick: card(
        sorted.length > 1 ? sorted[1] : sorted.first,
        RecommendationCardKind.volunteerPick,
      ),
    );
  }

  Future<RecommendationCard?> resolveLastPurchase({
    required String userId,
    String? categoryKey,
  }) async {
    try {
      var query = _client.from('elder_item_history').select().eq(
            'elder_user_id',
            userId,
          );
      if (categoryKey != null) {
        final cat = ProductCatalog.instance.categoryByKey(categoryKey);
        if (cat != null) {
          // view may not expose category_key; skip filter if fails
        }
      }
      final row = await query
          .order('last_fulfilled_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final itemId = row?['product_item_id']?.toString();
      if (itemId == null) return null;
      final item = await _client
          .from('product_items')
          .select('id, display_name, ref_price, brand_id')
          .eq('id', itemId)
          .maybeSingle();
      if (item == null) return null;
      return RecommendationCard(
        kind: RecommendationCardKind.frequent,
        productItemId: itemId,
        displayName: item['display_name']?.toString() ?? '',
        reason: '上次買的',
        refPrice: (item['ref_price'] as num?)?.toDouble(),
        brandId: item['brand_id']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
