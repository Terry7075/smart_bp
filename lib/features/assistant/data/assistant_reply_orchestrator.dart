import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_casual_chat_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_gemini_casual_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_intent.dart';
import 'package:smart_bp/features/assistant/data/assistant_reply_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/data/assistant_tone.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 統一小幫手：輕鬆語氣；自行判斷要不要查系統／帶路。
class AssistantReplyOrchestrator {
  AssistantReplyOrchestrator({
    AssistantReplyService? rules,
    AssistantCasualChatService? casual,
    AssistantGeminiCasualService? geminiCasual,
    AssistantShopActionService? shopAction,
  })  : _rules = rules ?? const AssistantReplyService(),
        _casual = casual ?? AssistantCasualChatService(),
        _geminiCasual = geminiCasual ?? AssistantGeminiCasualService(),
        _shopAction = shopAction;

  final AssistantReplyService _rules;
  final AssistantCasualChatService _casual;
  final AssistantGeminiCasualService _geminiCasual;
  final AssistantShopActionService? _shopAction;

  Future<({AssistantReply reply, String? userIntentLabel, String? assistantIntentLabel})>
      replyWithMeta({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
    String? userId,
  }) async {
    final shopClass = AssistantShopIntentClassifier.classify(question);
    if (_shopAction != null &&
        userId != null &&
        userId.isNotEmpty &&
        _useShopPipeline(shopClass)) {
      final shopReply = await _shopAction.handle(
        classification: shopClass,
        userId: userId,
        snapshot: snapshot,
      );
      return (
        reply: shopReply,
        userIntentLabel: shopClass.intentLabel,
        assistantIntentLabel: shopClass.intentLabel,
      );
    }

    final legacyReply = await reply(
      question: question,
      snapshot: snapshot,
      conversation: conversation,
    );
    final legacy = AssistantIntent.classify(question);
    final label = switch (legacy) {
      AssistantQueryKind.casual => '一般對話',
      AssistantQueryKind.systemData => '查詢系統資料',
      AssistantQueryKind.appGuide => 'App 帶路',
    };
    return (
      reply: legacyReply,
      userIntentLabel: label,
      assistantIntentLabel: label,
    );
  }

  bool _useShopPipeline(ShopIntentClassification c) {
    if (c.intent != AssistantShopIntent.casual) return true;
    final slots = c.slots;
    return slots != null && !slots.isEmpty;
  }

  Future<AssistantReply> reply({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
  }) async {
    final kind = AssistantIntent.classify(question);

    if (kind == AssistantQueryKind.casual) {
      try {
        final ai = await _geminiCasual.chat(
          question: question,
          snapshot: snapshot,
          conversation: conversation,
        );
        if (ai != null && ai.trim().isNotEmpty) {
          return AssistantReply(text: ai.trim());
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Assistant] Gemini casual fallback: $e');
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
}

final assistantReplyOrchestratorProvider =
    Provider<AssistantReplyOrchestrator>((ref) {
  return AssistantReplyOrchestrator(
    shopAction: ref.watch(assistantShopActionServiceProvider),
  );
});
