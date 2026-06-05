/// 三卡推薦：常買 / 便宜 / 志工推薦。
enum RecommendationCardKind { frequent, budget, volunteerPick }

final class RecommendationCard {
  const RecommendationCard({
    required this.kind,
    required this.productItemId,
    required this.displayName,
    required this.reason,
    this.refPrice,
    this.brandId,
    this.templateOptionId,
    this.imageUrl,
  });

  final RecommendationCardKind kind;
  final String productItemId;
  final String displayName;
  final String reason;
  final double? refPrice;
  final String? brandId;
  final String? templateOptionId;
  final String? imageUrl;

  factory RecommendationCard.fromRpcEntry(
    RecommendationCardKind kind,
    Map<String, dynamic>? entry,
  ) {
    if (entry == null || entry['product_item_id'] == null) {
      return RecommendationCard(
        kind: kind,
        productItemId: '',
        displayName: '暫無推薦',
        reason: _defaultReason(kind),
      );
    }
    return RecommendationCard(
      kind: kind,
      productItemId: entry['product_item_id']?.toString() ?? '',
      displayName: entry['display_name']?.toString() ?? '',
      reason: entry['reason']?.toString() ?? _defaultReason(kind),
      refPrice: (entry['ref_price'] as num?)?.toDouble(),
    );
  }

  static String _defaultReason(RecommendationCardKind k) => switch (k) {
        RecommendationCardKind.frequent => '您常買這款',
        RecommendationCardKind.budget => '全聯划算款',
        RecommendationCardKind.volunteerPick => '志工常幫買',
      };
}

final class RecommendationCardSet {
  const RecommendationCardSet({
    this.frequent,
    this.budget,
    this.volunteerPick,
  });

  final RecommendationCard? frequent;
  final RecommendationCard? budget;
  final RecommendationCard? volunteerPick;

  List<RecommendationCard> get nonEmpty => [
        if (frequent != null && frequent!.productItemId.isNotEmpty) frequent!,
        if (budget != null && budget!.productItemId.isNotEmpty) budget!,
        if (volunteerPick != null && volunteerPick!.productItemId.isNotEmpty)
          volunteerPick!,
      ];
}
