import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';

/// 小幫手一則完整回覆（文字 + 可選導航按鈕 + 品牌圖文選項）。
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.actions = const [],
    this.brandChoices = const [],
    this.categoryImageUrl,
  });

  final String text;
  final List<AssistantNavAction> actions;
  final List<AssistantBrandChoice> brandChoices;
  final String? categoryImageUrl;
}
