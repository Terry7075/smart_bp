import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/data/product_catalog.dart';

/// 品牌推薦結果。
final class BrandRecommendation {
  const BrandRecommendation({
    required this.brandId,
    required this.brandName,
    required this.displayName,
    required this.score,
    this.refPrice,
    this.templateOptionId,
  });

  final String brandId;
  final String brandName;
  final String displayName;
  final double score;
  final double? refPrice;
  final String? templateOptionId;
}

/// 加權線性推薦（社區購買 / 價格 / 志工代購）。
class RecommendationEngine {
  RecommendationEngine({ProductCatalog? catalog})
      : _catalog = catalog ?? ProductCatalog.instance;

  final ProductCatalog _catalog;

  static const wCommunity = 0.45;
  static const wPrice = 0.25;
  static const wVolunteer = 0.30;

  /// 本地推薦（無 DB 時使用模板順序 + ref_price）。
  List<BrandRecommendation> recommendLocal({
    required String categoryKey,
    int limit = 3,
  }) {
    final cat = _catalog.categoryByKey(categoryKey);
    if (cat == null) return const [];

    final candidates = cat.brands.where((b) => !b.isOther).toList();
    if (candidates.isEmpty) return const [];

    final maxPrice = candidates
        .map((b) => b.refPrice ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);

    final scored = <BrandRecommendation>[];
    for (var i = 0; i < candidates.length; i++) {
      final b = candidates[i];
      final community = 1.0 - (i / candidates.length);
      final volunteer = 1.0 - (i * 0.2).clamp(0.0, 0.8);
      final priceScore = b.refPrice == null || maxPrice <= 0
          ? 0.5
          : 1.0 - (b.refPrice! / maxPrice);
      final score = wCommunity * community +
          wVolunteer * volunteer +
          wPrice * priceScore;
      scored.add(
        BrandRecommendation(
          brandId: b.id,
          brandName: b.brandName,
          displayName: b.displayName,
          score: score,
          refPrice: b.refPrice,
          templateOptionId: b.templateOptionId,
        ),
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  /// Supabase RPC `recommend_brands`（需 migration + category UUID）。
  Future<List<BrandRecommendation>> recommendFromDb({
    String? locationPointId,
    required String categoryIdUuid,
    int limit = 3,
  }) async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'recommend_brands',
        params: {
          'p_location_point_id': locationPointId,
          'p_category_id': categoryIdUuid,
          'p_limit': limit,
        },
      );
      final list = List<dynamic>.from(raw as List? ?? const []);
      return [
        for (final e in list)
          if (e is Map)
            BrandRecommendation(
              brandId: e['brand_id']?.toString() ?? '',
              brandName: e['brand_name']?.toString() ?? '',
              displayName: e['display_name']?.toString() ?? '',
              score: (e['score'] as num?)?.toDouble() ?? 0,
              refPrice: (e['ref_price'] as num?)?.toDouble(),
              templateOptionId: e['template_option_id']?.toString(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> logRecommendationChoice({
    required String userId,
    required String? categoryIdUuid,
    required List<String> shownBrandIds,
    String? chosenBrandId,
  }) async {
    try {
      await Supabase.instance.client.from('recommendation_logs').insert({
        'user_id': userId,
        'category_id': categoryIdUuid,
        'shown_brand_ids': shownBrandIds,
        if (chosenBrandId != null) 'chosen_brand_id': chosenBrandId,
      });
    } catch (_) {}
  }
}
