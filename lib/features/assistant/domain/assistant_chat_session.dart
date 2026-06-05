import 'package:smart_bp/features/assistant/domain/assistant_message.dart';

/// 一場小幫手對話（可存入本機歷史）。
class AssistantChatSession {
  const AssistantChatSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.updatedAt,
    required this.title,
    required this.messages,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String title;
  final List<AssistantMessage> messages;

  bool get hasUserMessages => messages.any((m) => m.isUser);

  AssistantChatSession copyWith({
    DateTime? updatedAt,
    String? title,
    List<AssistantMessage>? messages,
  }) {
    return AssistantChatSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'started_at': startedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AssistantChatSession.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    final msgs = <AssistantMessage>[];
    if (rawMsgs is List) {
      for (final e in rawMsgs) {
        if (e is Map) {
          msgs.add(AssistantMessage.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return AssistantChatSession(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title']?.toString() ?? '對話紀錄',
      messages: msgs,
    );
  }
}
