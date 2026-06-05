import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/domain/recommendation_card.dart';
import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';
import 'package:smart_bp/features/shop/data/recommendation_engine.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';
import 'package:smart_bp/features/shop/presentation/widgets/recommendation_cards_widget.dart';
/// 柑仔店頂部三卡推薦（常買／便宜／志工）。
class ShopPersonalizedRecommendations extends ConsumerWidget {
  const ShopPersonalizedRecommendations({
    super.key,
    this.onAdded,
  });

  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider)?.user.id;
    if (userId == null) return const SizedBox.shrink();

    final async = ref.watch(
      personalizedRecommendationsProvider((userId: userId, categoryKey: null, categoryId: null)),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (set) {
        final cards = set.nonEmpty;
        if (cards.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: RecommendationCardsWidget(
              cards: cards,
              onSelect: (card) => _onSelect(context, ref, userId, card),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onSelect(
    BuildContext context,
    WidgetRef ref,
    String userId,
    RecommendationCard card,
  ) async {
    final set = ref.read(
      personalizedRecommendationsProvider(
        (userId: userId, categoryKey: null, categoryId: null),
      ),
    ).value;
    final shownIds = <String>[];
    if (set != null) {
      for (final c in set.nonEmpty) {
        if (c.brandId != null) shownIds.add(c.brandId!);
      }
    }
    await RecommendationEngine().logRecommendationChoice(
      userId: userId,
      categoryIdUuid: null,
      shownBrandIds: shownIds,
      chosenBrandId: card.brandId,
    );

    final snapshot = SupplyLineSnapshot(
      productId: 'item:${card.productItemId}',
      productName: card.displayName,
      quantity: 1,
      productItemId: card.productItemId,
      brand: card.displayName,
      referenceNote: card.reason,
    );
    try {
      await ref.read(demandRecordsRepositoryProvider).addSnapshotLinesResilient(
            userId: userId,
            lines: [snapshot],
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入需求：${card.displayName}')),
      );
      onAdded?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暫存失敗：$e')),
      );
    }
  }
}
