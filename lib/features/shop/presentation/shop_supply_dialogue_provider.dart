import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/data/shop_utterance_handler.dart';
import 'package:smart_bp/features/shop/data/supply_dialogue_service.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';

/// 柑仔店語音／文字：品類 → 品牌確認 → 寫入草稿（不直接送出志工）。
final class ShopSupplyDialogueState {
  const ShopSupplyDialogueState({
    this.pending,
    this.promptText,
    this.brandChoices = const [],
    this.categoryImageUrl,
    this.lastMessage,
    this.busy = false,
  });

  final PendingSupplyDialogue? pending;
  final String? promptText;
  final List<AssistantBrandChoice> brandChoices;
  final String? categoryImageUrl;
  final String? lastMessage;
  final bool busy;

  bool get awaitingBrand => pending != null && brandChoices.isNotEmpty;

  ShopSupplyDialogueState copyWith({
    PendingSupplyDialogue? pending,
    bool clearPending = false,
    String? promptText,
    List<AssistantBrandChoice>? brandChoices,
    String? categoryImageUrl,
    String? lastMessage,
    bool? busy,
  }) {
    return ShopSupplyDialogueState(
      pending: clearPending ? null : (pending ?? this.pending),
      promptText: promptText ?? this.promptText,
      brandChoices: brandChoices ?? this.brandChoices,
      categoryImageUrl: categoryImageUrl ?? this.categoryImageUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      busy: busy ?? this.busy,
    );
  }
}

class ShopSupplyDialogueNotifier extends Notifier<ShopSupplyDialogueState> {
  final _dialogue = SupplyDialogueService();

  @override
  ShopSupplyDialogueState build() => const ShopSupplyDialogueState();

  void clear() {
    state = const ShopSupplyDialogueState();
  }

  Future<String?> handleUtterance(String utterance) async {
    final text = utterance.trim();
    if (text.isEmpty) return '請說或輸入想買的東西';

    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return '請先登入';

    state = state.copyWith(busy: true, lastMessage: null);

    try {
      if (state.pending != null) {
        return await _continuePending(uid, text);
      }

      final started = _dialogue.tryStartFromUtterance(text);
      if (started != null) {
        _showBrandAsk(started);
        return null;
      }

      final nlu = await ref.read(hybridNluOrchestratorProvider).parse(text, userId: uid);
      final classification =
          ShopUtteranceHandler.classificationFromNlu(nlu, text);
      if (classification.intent == AssistantShopIntent.casual) {
        state = state.copyWith(busy: false);
        return '請說要買的商品，例如「我要衛生紙兩包」';
      }

      if (classification.intent == AssistantShopIntent.recordDemand) {
        final lines = classification.slots?.lines ?? const [];
        if (lines.isNotEmpty) {
          final line = lines.first;
          final pending = _dialogue.pendingFromDemandLine(
            line.productName,
            line.quantity,
          );
          if (pending != null) {
            _showBrandAsk(pending);
            return null;
          }
        }
      }

      final reply = await ref.read(shopUtteranceHandlerProvider).handle(
            userId: uid,
            utterance: text,
          );
      if (reply.brandChoices.isNotEmpty) {
        final lines = classification.slots?.lines ?? const [];
        final line = lines.isNotEmpty ? lines.first : null;
        final pending = line != null
            ? _dialogue.pendingFromDemandLine(line.productName, line.quantity)
            : _dialogue.tryStartFromUtterance(text);
        state = state.copyWith(
          busy: false,
          pending: pending,
          promptText: reply.text,
          brandChoices: reply.brandChoices,
          categoryImageUrl: reply.categoryImageUrl,
        );
        return null;
      }

      ref.invalidate(elderDemandDraftProvider);
      state = state.copyWith(
        busy: false,
        clearPending: true,
        brandChoices: const [],
        lastMessage: reply.text.split('\n').first,
      );
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return '處理失敗：$e';
    }
  }

  Future<String?> selectBrand(AssistantBrandChoice choice) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return '請先登入';
    final msg = choice.sendMessageOnTap ?? '${choice.index}';
    return handleUtterance(msg);
  }

  Future<String?> _continuePending(String uid, String text) async {
    final pending = state.pending!;
    final handled = _dialogue.handlePending(pending: pending, userText: text);

    if (handled.snapshot != null) {
      await ref.read(demandRecordsRepositoryProvider).addSnapshotLines(
            userId: uid,
            lines: [handled.snapshot!],
          );
      ref.invalidate(elderDemandDraftProvider);
      final msg = handled.reply?.text.split('\n').first ??
          '已加入採買清單';
      state = ShopSupplyDialogueState(lastMessage: msg);
      return null;
    }

    if (handled.reply != null) {
      state = state.copyWith(
        busy: false,
        pending: handled.next,
        promptText: handled.reply!.text,
        brandChoices: handled.reply!.brandChoices,
        categoryImageUrl: handled.reply!.categoryImageUrl,
      );
      return null;
    }

    state = state.copyWith(busy: false);
    return '無法辨識，請再選一次品牌';
  }

  void _showBrandAsk(PendingSupplyDialogue pending) {
    final ask = _dialogue.brandAskReplyFor(pending);
    state = ShopSupplyDialogueState(
      pending: pending,
      promptText: ask.text,
      brandChoices: ask.brandChoices,
      categoryImageUrl: ask.categoryImageUrl,
    );
  }
}

final shopSupplyDialogueProvider =
    NotifierProvider<ShopSupplyDialogueNotifier, ShopSupplyDialogueState>(
  ShopSupplyDialogueNotifier.new,
);
