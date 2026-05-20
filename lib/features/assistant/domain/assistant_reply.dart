import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';

/// 小幫手一則完整回覆（文字 + 可選導航按鈕）。
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.actions = const [],
  });

  final String text;
  final List<AssistantNavAction> actions;
}
