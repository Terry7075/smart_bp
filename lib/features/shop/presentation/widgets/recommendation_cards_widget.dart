import 'package:flutter/material.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/shop/domain/recommendation_card.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';

/// 三卡推薦（常買 / 便宜 / 志工）— 複用 [BrandChoiceList]。
class RecommendationCardsWidget extends StatelessWidget {
  const RecommendationCardsWidget({
    super.key,
    required this.cards,
    this.onSelect,
    this.enabled = true,
  });

  final List<RecommendationCard> cards;
  final void Function(RecommendationCard card)? onSelect;
  final bool enabled;

  static List<AssistantBrandChoice> toBrandChoices(List<RecommendationCard> cards) {
    var i = 1;
    return [
      for (final c in cards)
        if (c.productItemId.isNotEmpty)
          AssistantBrandChoice(
            index: i++,
            optionId: c.productItemId,
            label: _kindLabel(c.kind),
            subtitle: c.displayName,
            priceHint: c.refPrice != null ? '約 \$${c.refPrice!.toStringAsFixed(0)}' : null,
            sendMessageOnTap: c.displayName,
          ),
    ];
  }

  static String _kindLabel(RecommendationCardKind k) => switch (k) {
        RecommendationCardKind.frequent => '常買款',
        RecommendationCardKind.budget => '便宜款',
        RecommendationCardKind.volunteerPick => '志工推薦',
      };

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final choices = toBrandChoices(cards);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            '為您推薦（點選即可）',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        BrandChoiceList(
          choices: choices,
          enabled: enabled,
          onTapChoice: onSelect == null
              ? null
              : (choice) {
                  final idx = choice.index - 1;
                  if (idx >= 0 && idx < cards.length) onSelect!(cards[idx]);
                },
        ),
      ],
    );
  }
}
