import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 智慧小幫手雲端兜底：Supabase Edge `assistant_casual_chat`（Gemini）。
class AssistantGeminiCasualService {
  AssistantGeminiCasualService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const enabled = bool.fromEnvironment(
    'ASSISTANT_CASUAL_GEMINI',
    defaultValue: true,
  );

  static const _clientTimeout = Duration(seconds: 28);

  Future<({String? reply, String? error})> chat({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
    String? contextSummary,
  }) async {
    if (!enabled) {
      return (reply: null, error: 'ASSISTANT_CASUAL_GEMINI disabled');
    }

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
      final res = await _client.functions
          .invoke(
            'assistant_casual_chat',
            body: {
              'question': question,
              if (snapshot.displayName != null &&
                  snapshot.displayName!.isNotEmpty)
                'display_name': snapshot.displayName,
              if (contextSummary != null && contextSummary.trim().isNotEmpty)
                'context_summary': contextSummary.trim(),
              'messages': messages,
            },
          )
          .timeout(_clientTimeout);

      if (res.status != 200) {
        final detail = _errorDetail(res);
        if (kDebugMode) {
          debugPrint(
            'AssistantGeminiCasualService: status=${res.status} $detail',
          );
        }
        return (reply: null, error: detail ?? 'status ${res.status}');
      }
      final data = res.data;
      if (data is! Map) {
        return (reply: null, error: 'invalid response');
      }
      final reply = data['reply']?.toString().trim();
      if (reply == null || reply.isEmpty) {
        return (reply: null, error: 'empty reply');
      }
      return (reply: reply, error: null);
    } on TimeoutException {
      return (reply: null, error: 'timeout');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AssistantGeminiCasualService: $e\n$st');
      }
      return (reply: null, error: e.toString());
    }
  }

  String? _errorDetail(FunctionResponse res) {
    final data = res.data;
    if (data is Map) {
      final err = data['error']?.toString();
      final detail = data['detail']?.toString();
      if (err != null && detail != null) return '$err: $detail';
      if (err != null) return err;
      if (detail != null) return detail;
    }
    return null;
  }
}
