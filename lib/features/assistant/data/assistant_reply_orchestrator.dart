import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_casual_chat_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_intent.dart';
import 'package:smart_bp/features/assistant/data/assistant_reply_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_tone.dart';
import 'package:smart_bp/features/assistant/data/ollama_client.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 是否啟用本機 Ollama（需 ollama serve；預設關閉）。
///
/// 開發可試：`flutter run -d chrome --dart-define=ASSISTANT_CASUAL_AI=true`
const bool kAssistantCasualAi =
    bool.fromEnvironment('ASSISTANT_CASUAL_AI', defaultValue: false);

/// 統一小幫手：輕鬆語氣；自行判斷要不要查系統／帶路。
class AssistantReplyOrchestrator {
  AssistantReplyOrchestrator({
    AssistantReplyService? rules,
    AssistantCasualChatService? casual,
    OllamaClient? ollama,
  })  : _rules = rules ?? const AssistantReplyService(),
        _casual = casual ?? AssistantCasualChatService(),
        _ollama = ollama ?? OllamaClient();

  final AssistantReplyService _rules;
  final AssistantCasualChatService _casual;
  final OllamaClient _ollama;

  Future<AssistantReply> reply({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
  }) async {
    final kind = AssistantIntent.classify(question);

    if (kind == AssistantQueryKind.casual) {
      if (kAssistantCasualAi) {
        try {
          final online = await _ollama.ping();
          if (online) {
            final ai = await _ollamaCasualChat(
              question: question,
              snapshot: snapshot,
              conversation: conversation,
            );
            if (ai != null && ai.trim().isNotEmpty) {
              return AssistantReply(text: ai.trim());
            }
          }
        } catch (e) {
          debugPrint('[Assistant] Ollama fallback: $e');
        }
      }

      return _casual.reply(
        question: question,
        snapshot: snapshot,
        conversation: conversation,
      );
    }

    final factual = _rules.reply(question, snapshot);
    return AssistantTone.warmify(
      factual,
      kind: kind,
      snapshot: snapshot,
      question: question,
    );
  }

  Future<String?> _ollamaCasualChat({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
  }) async {
    final name = (snapshot.displayName ?? '').trim();
    final who = name.isNotEmpty ? '使用者叫做$name，' : '';
    final system = '''
你是明德 e 達人社區 App 的小幫手，用繁體中文、口語、親切陪長輩聊天。
$who語氣像鄰居，不要像客服制式稿；每次 2～4 句，不超過 100 字。
若對方問藥單、代購、App 功能，可輕鬆帶一句「要我幫您查進度也可以說」。
不可捏造醫療建議；健康問題請建議洽醫師。''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system.trim()},
    ];

    for (final m in conversation) {
      if (m.text.trim().isEmpty) continue;
      messages.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }

    return _ollama.chat(messages: messages);
  }
}

final assistantReplyOrchestratorProvider =
    Provider<AssistantReplyOrchestrator>((ref) => AssistantReplyOrchestrator());

final ollamaClientProvider = Provider<OllamaClient>((ref) => OllamaClient());
