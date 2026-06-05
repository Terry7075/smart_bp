import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 閒聊模式：Supabase Edge `assistant_casual_chat`（Gemini），適合手機 App。
class AssistantGeminiCasualService {
  AssistantGeminiCasualService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 是否啟用雲端閒聊（預設開；離線 Demo 可 `--dart-define=ASSISTANT_CASUAL_GEMINI=false`）。
  static const enabled = bool.fromEnvironment(
    'ASSISTANT_CASUAL_GEMINI',
    defaultValue: true,
  );

  Future<String?> chat({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
  }) async {
    if (!enabled) return null;

    final messages = <Map<String, String>>[];
    for (final m in conversation) {
      final t = m.text.trim();
      if (t.isEmpty) continue;
      messages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': t,
      });
    }

    try {
      final res = await _client.functions.invoke(
        'assistant_casual_chat',
        body: {
          'question': question,
          if (snapshot.displayName != null && snapshot.displayName!.isNotEmpty)
            'display_name': snapshot.displayName,
          'messages': messages,
        },
      );
      if (res.status != 200) return null;
      final data = res.data;
      if (data is! Map) return null;
      final reply = data['reply']?.toString().trim();
      if (reply == null || reply.isEmpty) return null;
      return reply;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AssistantGeminiCasualService: $e\n$st');
      }
      return null;
    }
  }
}
