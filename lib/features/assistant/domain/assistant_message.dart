import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';

/// 小幫手對話中的一則訊息。
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    required this.at,
    this.actions = const [],
    this.intentLabel,
  });

  final AssistantMessageRole role;
  final String text;
  final DateTime at;

  /// 助手訊息可附一鍵帶路按鈕（使用者訊息通常為空）。
  final List<AssistantNavAction> actions;

  /// 第五章：意圖類別標籤（記錄需求／查價／查看／取消／一般對話等）。
  final String? intentLabel;

  bool get isUser => role == AssistantMessageRole.user;
  bool get isAssistant => role == AssistantMessageRole.assistant;

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        'actions': actions.map((a) => a.toJson()).toList(),
        if (intentLabel != null) 'intent_label': intentLabel,
      };

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role']?.toString() ?? 'assistant';
    final role = AssistantMessageRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => AssistantMessageRole.assistant,
    );
    final rawActions = json['actions'];
    final actions = <AssistantNavAction>[];
    if (rawActions is List) {
      for (final e in rawActions) {
        if (e is Map) {
          actions.add(
            AssistantNavAction.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return AssistantMessage(
      role: role,
      text: json['text']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      actions: actions,
      intentLabel: json['intent_label']?.toString(),
    );
  }
}

enum AssistantMessageRole { user, assistant }
