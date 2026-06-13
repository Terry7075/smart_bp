/// 小幫手統一智慧模式（代購／藥單走規則；閒聊與未命中規則由 Gemini 兜底）。
enum AssistantChatMode {
  smart,
}

extension AssistantChatModeUi on AssistantChatMode {
  String get title => '智慧小幫手';

  String get subtitle => '代購・藥單・閒聊';
}
