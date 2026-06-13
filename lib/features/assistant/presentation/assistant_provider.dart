import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_dialog_context.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/data/assistant_hints.dart';
import 'package:smart_bp/features/assistant/data/assistant_history_repository.dart';
import 'package:smart_bp/features/assistant/data/assistant_reply_orchestrator.dart';
import 'package:smart_bp/features/assistant/data/assistant_snapshot_loader.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_bp/features/shop/data/supply_dialogue_service.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/features/shop/presentation/widgets/recommendation_cards_widget.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_history_provider.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// 小幫手查詢 Supabase 失敗時拋出。
class AssistantException implements Exception {
  AssistantException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AssistantChatState {
  const AssistantChatState({
    this.messages = const [],
    this.loading = false,
    this.viewingHistory = false,
    this.activeSessionId,
    this.selectedHistoryId,
    this.pendingSupply,
    this.clarificationSessionId,
    this.clarificationPartial,
  });

  final List<AssistantMessage> messages;
  final bool loading;

  /// 正在側邊欄點選的舊紀錄（唯讀，不可繼續輸入）。
  final bool viewingHistory;

  /// 目前這一場新對話的 id（登入後新開）。
  final String? activeSessionId;

  /// 側邊欄選中的歷史場次 id。
  final String? selectedHistoryId;
  final PendingSupplyDialogue? pendingSupply;

  /// Hybrid NLU 多輪澄清（對應 `clarification_sessions`）。
  final String? clarificationSessionId;
  final ShopNluResult? clarificationPartial;

  bool get isFreshWelcome =>
      !viewingHistory && messages.length <= 1 && !messages.any((m) => m.isUser);

  AssistantChatState copyWith({
    List<AssistantMessage>? messages,
    bool? loading,
    bool? viewingHistory,
    String? activeSessionId,
    String? selectedHistoryId,
    bool clearSelectedHistory = false,
    PendingSupplyDialogue? pendingSupply,
    bool clearPendingSupply = false,
    String? clarificationSessionId,
    ShopNluResult? clarificationPartial,
    bool clearClarification = false,
  }) {
    return AssistantChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      viewingHistory: viewingHistory ?? this.viewingHistory,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      selectedHistoryId: clearSelectedHistory
          ? null
          : (selectedHistoryId ?? this.selectedHistoryId),
      pendingSupply: clearPendingSupply
          ? null
          : (pendingSupply ?? this.pendingSupply),
      clarificationSessionId: clearClarification
          ? null
          : (clarificationSessionId ?? this.clarificationSessionId),
      clarificationPartial: clearClarification
          ? null
          : (clarificationPartial ?? this.clarificationPartial),
    );
  }
}

class AssistantChat extends Notifier<AssistantChatState> {
  String? _boundUserId;
  String? _activeSessionId;
  List<AssistantMessage>? _pausedActiveMessages;

  @override
  AssistantChatState build() {
    ref.listen<Session?>(authProvider, (prev, next) {
      final uid = next?.user.id;
      if (uid != _boundUserId) {
        _handleUserChanged(uid);
      }
    });

    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) {
      _boundUserId = null;
      _activeSessionId = null;
      return const AssistantChatState();
    }

    if (_boundUserId != uid) {
      _boundUserId = uid;
      _activeSessionId = const Uuid().v4();
      return _welcomeState(sessionId: _activeSessionId!);
    }

    _activeSessionId ??= const Uuid().v4();
    if (state.messages.isEmpty) {
      return _welcomeState(sessionId: _activeSessionId!);
    }
    return state;
  }

  Future<void> _handleUserChanged(String? uid) async {
    await _archiveActiveSessionIfNeeded();
    _boundUserId = uid;
    _activeSessionId = uid != null ? const Uuid().v4() : null;
    if (uid == null) {
      state = const AssistantChatState();
      return;
    }
    state = _welcomeState(sessionId: _activeSessionId!);
    ref.invalidate(assistantHistoryListProvider);
  }

  AssistantChatState _welcomeState({required String sessionId}) {
    return AssistantChatState(
      activeSessionId: sessionId,
      viewingHistory: false,
      selectedHistoryId: null,
      messages: [
        AssistantMessage(
          role: AssistantMessageRole.assistant,
          text: AssistantHints.welcomeMessage,
          at: DateTime.now(),
          actions: const [
            AssistantNavAction(label: '前往柑仔店', route: '/shop'),
            AssistantNavAction(label: '前往健康', route: '/home', homeTab: 3),
            AssistantNavAction(label: '個人資料', route: '/profile'),
          ],
        ),
      ],
    );
  }

  String? get _userId => ref.read(authProvider)?.user.id;

  Future<void> startNewConversation() async {
    await _archiveActiveSessionIfNeeded();
    _pausedActiveMessages = null;
    _activeSessionId = const Uuid().v4();
    state = _welcomeState(sessionId: _activeSessionId!);
    ref.invalidate(assistantHistoryListProvider);
  }

  /// 點側邊欄「進行中」或繼續編輯該場對話（可繼續輸入）。
  void continueSession(AssistantChatSession session) {
    _pausedActiveMessages = null;
    _activeSessionId = session.id;
    state = AssistantChatState(
      messages: List<AssistantMessage>.from(session.messages),
      viewingHistory: false,
      selectedHistoryId: null,
      activeSessionId: session.id,
    );
  }

  /// 僅查看舊紀錄（唯讀）。
  void openHistorySession(AssistantChatSession session) {
    final activeId = state.activeSessionId ?? _activeSessionId;
    if (session.id == activeId && session.hasUserMessages) {
      continueSession(session);
      return;
    }
    if (!state.viewingHistory) {
      _pausedActiveMessages = List<AssistantMessage>.from(state.messages);
    }
    state = AssistantChatState(
      messages: session.messages,
      viewingHistory: true,
      selectedHistoryId: session.id,
      activeSessionId: _activeSessionId,
    );
  }

  void returnToActiveChat() {
    _activeSessionId ??= const Uuid().v4();
    final paused = _pausedActiveMessages;
    _pausedActiveMessages = null;
    if (paused != null && paused.isNotEmpty) {
      state = AssistantChatState(
        messages: paused,
        viewingHistory: false,
        activeSessionId: _activeSessionId,
        selectedHistoryId: null,
      );
      return;
    }
    state = _welcomeState(sessionId: _activeSessionId!);
  }

  /// 登出／切帳號／明確開新對話時才結案存檔（不在每次離開頁面時結案）。
  Future<void> _archiveActiveSessionIfNeeded() async {
    if (state.viewingHistory) return;
    await _persistActiveSession();
  }

  Future<void> deleteHistorySession(String sessionId) async {
    final userId = _userId;
    if (userId == null || sessionId.isEmpty) return;

    final activeId = state.activeSessionId ?? _activeSessionId;
    await ref.read(assistantHistoryRepositoryProvider).deleteSession(
          userId: userId,
          sessionId: sessionId,
        );

    if (activeId == sessionId ||
        state.selectedHistoryId == sessionId ||
        (state.viewingHistory && state.selectedHistoryId == sessionId)) {
      _pausedActiveMessages = null;
      _activeSessionId = const Uuid().v4();
      state = _welcomeState(sessionId: _activeSessionId!);
    }

    ref.invalidate(assistantHistoryListProvider);
  }

  String _sessionTitle(List<AssistantMessage> messages) {
    for (final m in messages) {
      if (m.isUser) {
        final t = m.text.trim();
        if (t.length <= 24) return t;
        return '${t.substring(0, 24)}…';
      }
    }
    return '對話紀錄';
  }

  Future<void> sendUserMessage(String raw) async {
    if (state.viewingHistory) return;

    final text = raw.trim();
    if (text.isEmpty || state.loading) return;

    final shopPreview = AssistantShopIntentClassifier.classify(text);
    final userMsg = AssistantMessage(
      role: AssistantMessageRole.user,
      text: text,
      at: DateTime.now(),
      intentLabel: shopPreview.intent != AssistantShopIntent.casual ||
              (shopPreview.slots != null && !shopPreview.slots!.isEmpty)
          ? shopPreview.intentLabel
          : null,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      loading: true,
    );

    try {
      final snapshot =
          await ref.read(assistantSnapshotLoaderProvider).load();
      final resolved = AssistantDialogContext.resolve(
        question: text,
        conversation: state.messages,
      );
      final userId = _userId;
      final supplyDialogue = SupplyDialogueService();

      if (state.pendingSupply != null) {
        final pending = state.pendingSupply!;
        final handled = supplyDialogue.handlePending(
          pending: pending,
          userText: resolved,
        );
        if (handled.snapshot != null && userId != null) {
          await ref.read(demandRecordsRepositoryProvider).addSnapshotLinesResilient(
                userId: userId,
                lines: [handled.snapshot!],
              );
          ref.invalidate(elderDemandDraftProvider);
        }
        final reply = handled.reply;
        if (reply != null) {
          final savedDraft =
              handled.next == null && handled.snapshot != null;
          final assistantMsg = AssistantMessage(
            role: AssistantMessageRole.assistant,
            text: reply.text,
            at: DateTime.now(),
            actions: reply.brandChoices.isNotEmpty || savedDraft
                ? AssistantShopNavigation.followUpActions(
                    extra: reply.actions,
                    includeOrders: savedDraft,
                  )
                : reply.actions,
            intentLabel: '記錄需求',
            brandChoices: reply.brandChoices,
            categoryImageUrl: reply.categoryImageUrl,
          );
          state = state.copyWith(
            messages: [...state.messages, assistantMsg],
            loading: false,
            pendingSupply: handled.next,
            clearPendingSupply: savedDraft,
          );
          await _persistActiveSession();
          return;
        }
      }

      if (userId != null &&
          shopPreview.intent == AssistantShopIntent.recordDemand) {
        final turn =
            await ref.read(clarificationDialogueServiceProvider).handleUtterance(
                  userId: userId,
                  utterance: resolved,
                  sessionId: state.clarificationSessionId,
                  existingPartial: state.clarificationPartial,
                );
        ref.read(shopNluResultProvider.notifier).setResult(turn.partial);
        if (turn.snapshot != null) {
          await ref
              .read(demandRecordsRepositoryProvider)
              .addSnapshotLinesResilient(
                userId: userId,
                lines: [turn.snapshot!],
              );
          ref.invalidate(elderDemandDraftProvider);
          final assistantMsg = AssistantMessage(
            role: AssistantMessageRole.assistant,
            text: '${turn.reply?.text ?? '已記下「${turn.snapshot!.productName}」。'}\n'
                '請到柑仔店按「送出給志工」。',
            at: DateTime.now(),
            actions: AssistantShopNavigation.followUpActions(includeOrders: true),
            intentLabel: kDebugMode
                ? '記錄需求 · NLU ${(turn.partial.confidence * 100).toStringAsFixed(0)}%'
                : '記錄需求',
          );
          state = state.copyWith(
            messages: [...state.messages, assistantMsg],
            loading: false,
            clearClarification: true,
          );
          await _persistActiveSession();
          return;
        }
        if (turn.reply != null) {
          final choices = turn.recommendationCards != null
              ? RecommendationCardsWidget.toBrandChoices(
                  turn.recommendationCards!,
                )
              : <AssistantBrandChoice>[];
          final assistantMsg = AssistantMessage(
            role: AssistantMessageRole.assistant,
            text: '${turn.reply!.text}\n'
                '（選好後可到柑仔店按「送出給志工」）',
            at: DateTime.now(),
            actions: choices.isNotEmpty
                ? AssistantShopNavigation.followUpActions(
                    extra: turn.reply!.actions,
                  )
                : turn.reply!.actions,
            intentLabel: kDebugMode
                ? '記錄需求 · NLU ${(turn.partial.confidence * 100).toStringAsFixed(0)}%'
                : '記錄需求',
            brandChoices: choices,
          );
          state = state.copyWith(
            messages: [...state.messages, assistantMsg],
            loading: false,
            clarificationSessionId: turn.sessionId,
            clarificationPartial: turn.partial,
          );
          await _persistActiveSession();
          return;
        }
      }

      final started = supplyDialogue.tryStartFromUtterance(resolved);
      if (started != null) {
        final ask = supplyDialogue.brandAskReplyFor(started);
        final assistantMsg = AssistantMessage(
          role: AssistantMessageRole.assistant,
          text: '${ask.text}\n'
              '（選好品牌後，可按下方「前往柑仔店送出」）',
          at: DateTime.now(),
          actions: AssistantShopNavigation.followUpActions(extra: ask.actions),
          intentLabel: '記錄需求',
          brandChoices: ask.brandChoices,
          categoryImageUrl: ask.categoryImageUrl,
        );
        state = state.copyWith(
          messages: [...state.messages, assistantMsg],
          loading: false,
          pendingSupply: started,
        );
        await _persistActiveSession();
        return;
      }

      final meta = await ref.read(assistantReplyOrchestratorProvider).replyWithMeta(
            question: resolved,
            snapshot: snapshot,
            conversation: state.messages,
            userId: userId,
          );
      final reply = meta.reply;
      final brandFollowUp = reply.brandChoices.isNotEmpty;
      final draftSaved = reply.text.contains('採買清單');
      PendingSupplyDialogue? newPending;
      if (brandFollowUp) {
        newPending = supplyDialogue.tryStartFromUtterance(resolved);
        if (newPending == null) {
          final classified = AssistantShopIntentClassifier.classify(resolved);
          final lines = classified.slots?.lines ?? const [];
          if (lines.isNotEmpty) {
            newPending = supplyDialogue.pendingFromDemandLine(
              lines.first.productName,
              lines.first.quantity,
            );
          }
        }
      }
      final assistantMsg = AssistantMessage(
        role: AssistantMessageRole.assistant,
        text: brandFollowUp
            ? '${reply.text}\n（選好品牌後，可按下方「前往柑仔店送出」）'
            : reply.text,
        at: DateTime.now(),
        actions: brandFollowUp || draftSaved
            ? AssistantShopNavigation.followUpActions(
                extra: reply.actions,
                includeOrders: draftSaved && !brandFollowUp,
              )
            : reply.actions,
        intentLabel: meta.assistantIntentLabel,
        brandChoices: reply.brandChoices,
        categoryImageUrl: reply.categoryImageUrl,
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        loading: false,
        pendingSupply: newPending ?? state.pendingSupply,
        clearPendingSupply: draftSaved && !brandFollowUp,
      );
      if (draftSaved) {
        ref.invalidate(elderDemandDraftProvider);
      }
      await _persistActiveSession();
    } catch (e) {
      state = state.copyWith(loading: false);
      throw AssistantException(
        '暫時讀不到您的資料，請確認已登入並稍後再試。',
        cause: e,
      );
    }
  }

  Future<void> _persistActiveSession() async {
    final userId = _userId;
    final sessionId = state.activeSessionId ?? _activeSessionId;
    if (userId == null || sessionId == null) return;
    if (!state.messages.any((m) => m.isUser)) return;

    final session = AssistantChatSession(
      id: sessionId,
      userId: userId,
      startedAt: state.messages.first.at,
      updatedAt: DateTime.now(),
      title: _sessionTitle(state.messages),
      messages: List<AssistantMessage>.from(state.messages),
    );
    await ref.read(assistantHistoryRepositoryProvider).upsertSession(session);
    ref.invalidate(assistantHistoryListProvider);
  }

  /// 離開小幫手頁：只同步雲端，不結束目前對話（回來可繼續聊）。
  Future<void> onPageDispose() async {
    if (state.viewingHistory) return;
    await _persistActiveSession();
  }
}

final assistantChatProvider =
    NotifierProvider<AssistantChat, AssistantChatState>(AssistantChat.new);
