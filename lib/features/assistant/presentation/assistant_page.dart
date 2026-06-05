import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/data/assistant_hints.dart';
import 'package:smart_bp/features/assistant/data/assistant_navigation.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_navigation.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_history_sidebar.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_history_provider.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_provider.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_tts_provider.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/assistant/presentation/widgets/assistant_voice_live_panel.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';
import 'package:smart_bp/shared/widgets/mindu_big_button.dart';

/// 明德 e 達人 — 依 Supabase 資料回答的小幫手（長輩友善大字）。
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _orangeAccent = Color(0xFFE65100);
  static const Color _cream = Color(0xFFFFF8E1);

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _drawerKey = GlobalKey<ScaffoldState>();

  static const double _sidebarBreakpoint = 720;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assistantVoiceProvider.notifier).ensureInitialized();
    });
  }

  @override
  void dispose() {
    ref.read(assistantVoiceProvider.notifier).cancelListening();
    ref.read(assistantTtsProvider.notifier).stop();
    ref.read(assistantChatProvider.notifier).onPageDispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleVoice() async {
    // 語音收音前停止 TTS，避免回音
    await ref.read(assistantTtsProvider.notifier).stop();
    final voice = ref.read(assistantVoiceProvider.notifier);
    final ended = await voice.toggleListening();
    if (ended != null && ended.isNotEmpty && mounted) {
      _input.text = ended;
      await _send(ended);
    }
  }

  Future<void> _confirmVoice() async {
    final text =
        await ref.read(assistantVoiceProvider.notifier).finishListening();
    if (!mounted || text == null || text.isEmpty) return;
    _input.text = text;
    await _send(text);
  }

  Future<void> _cancelVoice() async {
    await ref.read(assistantVoiceProvider.notifier).cancelListening();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    if (preset == null) {
      _input.clear();
    }
    try {
      await ref.read(assistantChatProvider.notifier).sendUserMessage(text);
      _scrollToBottom();
    } on AssistantException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
          content: Text(
            e.message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(assistantChatProvider);
    final voice = ref.watch(assistantVoiceProvider);

    ref.listen(assistantVoiceProvider, (prev, next) {
      if (next.isListening && next.liveText != _input.text) {
        _input.value = TextEditingValue(
          text: next.liveText,
          selection: TextSelection.collapsed(offset: next.liveText.length),
        );
      }
      final err = next.errorMessage;
      if (err != null && err != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              err,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    });

    ref.listen(assistantChatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != next.messages.length) {
        _scrollToBottom();
        // 新回覆到達時，若 TTS 啟用則自動播報最後一條 bot 訊息
        if (!next.loading && next.messages.isNotEmpty) {
          final last = next.messages.last;
          if (!last.isUser) {
            // 只播報第一行（避免播報過長）
            final firstLine = last.text.split('\n').first.trim();
            ref.read(assistantTtsProvider.notifier).speak(firstLine);
          }
        }
      }
    });

    final tts = ref.watch(assistantTtsProvider);
    final wide = MediaQuery.sizeOf(context).width >= _sidebarBreakpoint;
    final showHelp = chat.isFreshWelcome && !chat.viewingHistory;
    final inputEnabled =
        !chat.loading && !chat.viewingHistory && !voice.isListening;

    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: Scaffold(
        key: _drawerKey,
        backgroundColor: _cream,
        drawer: wide
            ? null
            : Drawer(
                width: 300,
                child: AssistantHistorySidebar(
                  onCloseDrawer: () => Navigator.of(context).pop(),
                ),
              ),
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 30),
            onPressed: () => context.pop(),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy, size: 30),
              SizedBox(width: 10),
              Text(
                '小幫手',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
          toolbarHeight: 64,
          actions: [
            if (!wide)
              IconButton(
                tooltip: '過往對話',
                icon: const Icon(Icons.history, size: 30),
                onPressed: () => _drawerKey.currentState?.openDrawer(),
              ),
            IconButton(
              tooltip: tts.enabled ? '關閉播報' : '開啟播報',
              icon: Icon(
                tts.speaking
                    ? Icons.volume_up
                    : (tts.enabled ? Icons.volume_up_outlined : Icons.volume_off),
                size: 28,
                color: tts.enabled ? Colors.white : Colors.white54,
              ),
              onPressed: () => ref.read(assistantTtsProvider.notifier).toggleEnabled(),
            ),
            IconButton(
              tooltip: '新對話',
              icon: const Icon(Icons.add_comment_outlined, size: 28),
              onPressed: chat.loading
                  ? null
                  : () => ref
                      .read(assistantChatProvider.notifier)
                      .startNewConversation(),
            ),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              const SizedBox(
                width: 300,
                child: AssistantHistorySidebar(),
              ),
            if (wide)
              const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Column(
                children: [
                  if (chat.viewingHistory)
                    Material(
                      color: const Color(0xFFFFF3E0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history,
                              color: Color(0xFFE65100),
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '正在查看過往對話（僅供閱讀）',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(assistantChatProvider.notifier)
                                  .returnToActiveChat(),
                              child: const Text(
                                '回到目前對話',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final id = chat.selectedHistoryId;
                                if (id == null) return;
                                final sessions = ref
                                    .read(assistantHistoryListProvider)
                                    .value;
                                final match = sessions
                                    ?.where((s) => s.id == id)
                                    .toList();
                                if (match == null || match.isEmpty) return;
                                ref
                                    .read(assistantChatProvider.notifier)
                                    .continueSession(match.first);
                              },
                              child: const Text(
                                '繼續此對話',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: chat.messages.length +
                          (chat.loading ? 1 : 0) +
                          (showHelp ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showHelp && index == 0) {
                          return _AssistantHelpPanel(
                            loading: chat.loading,
                            onAsk: _send,
                          );
                        }
                        final msgIndex = showHelp ? index - 1 : index;
                        if (chat.loading && msgIndex == chat.messages.length) {
                          return const _TypingBubble();
                        }
                        final msg = chat.messages[msgIndex];
                        return _MessageBubble(
                          message: msg,
                          onNavigate: _scrollToBottom,
                          actionsEnabled: !chat.viewingHistory,
                        );
                      },
                    ),
                  ),
                  if (!chat.viewingHistory && chat.pendingSupply != null)
                    Material(
                      color: const Color(0xFFE8F5E9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.touch_app,
                              color: Color(0xFF2E7D32),
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '正在確認品牌：選完後請到柑仔店送出',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: () => assistantNavigate(
                                context,
                                ref,
                                AssistantShopNavigation.submit,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                              child: const Text(
                                '柑仔店送出',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!chat.viewingHistory && voice.isListening)
                    AssistantVoiceLivePanel(
                      onConfirm: _confirmVoice,
                      onCancel: _cancelVoice,
                    ),
                  if (!chat.viewingHistory)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Material(
                            color: voice.isListening
                                ? const Color(0xFFC62828)
                                : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: inputEnabled || voice.isListening
                                  ? _toggleVoice
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(
                                  voice.isListening ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _input,
                              enabled: inputEnabled,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        hintText: AssistantHints.inputHint,
                        hintStyle: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _green),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _green.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: _green,
                            width: 2,
                          ),
                        ),
                      ),
                              onSubmitted:
                                  inputEnabled ? (_) => _send() : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: inputEnabled ? _orangeAccent : Colors.grey,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: inputEnabled ? () => _send() : null,
                              borderRadius: BorderRadius.circular(16),
                              child: const SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: MinduBigButton(
                      text: '返回首頁',
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 進入小幫手時顯示：能做什麼 + 常見問題一鍵提問。
class _AssistantHelpPanel extends StatelessWidget {
  const _AssistantHelpPanel({
    required this.loading,
    required this.onAsk,
  });

  final bool loading;
  final void Function(String question) onAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '我能幫您什麼？',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              ...AssistantHints.capabilities.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              c.subtitle,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.35,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              const Text(
                AssistantHints.helpPanelTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 10),
              ...AssistantHints.sampleQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: loading ? null : () => onAsk(q),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFFE65100),
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                q,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.touch_app,
                              color: Color(0xFF5D4037),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                AssistantHints.helpPanelFootnote,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    this.onNavigate,
    this.actionsEnabled = true,
  });

  final AssistantMessage message;
  final VoidCallback? onNavigate;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(assistantTtsProvider);
    final isUser = message.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? const Color(0xFF2E7D32) : Colors.white;
    final fg = isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy, size: 22, color: Color(0xFFE65100)),
                  SizedBox(width: 6),
                  Text(
                    '小幫手',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.88,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (!isUser && message.categoryImageUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      message.categoryImageUrl!,
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                if (!isUser && message.brandChoices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BrandChoiceList(
                    choices: message.brandChoices,
                    enabled: actionsEnabled,
                    onTapChoice: actionsEnabled
                        ? (c) {
                            final msg = c.sendMessageOnTap ?? '${c.index}';
                            ref
                                .read(assistantChatProvider.notifier)
                                .sendUserMessage(msg);
                          }
                        : null,
                  ),
                  if (actionsEnabled) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        assistantNavigate(
                          context,
                          ref,
                          AssistantShopNavigation.submit,
                        );
                        onNavigate?.call();
                      },
                      icon: const Icon(Icons.storefront, size: 22),
                      label: const Text(
                        '選好品牌後，前往柑仔店送出',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
                if (message.intentLabel != null &&
                    message.intentLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '意圖：${message.intentLabel}',
                    style: TextStyle(
                      fontSize: 14,
                      color: fg.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (!isUser && actionsEnabled) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => ref.read(assistantTtsProvider.notifier).speak(
                          message.text,
                          forceSpeak: true,
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tts.speaking ? Icons.volume_up : Icons.volume_up_outlined,
                          size: 22,
                          color: const Color(0xFF5D4037),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '重播',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (actionsEnabled &&
                    !isUser &&
                    message.actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.actions.map((action) {
                      return FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F5E9),
                          foregroundColor: const Color(0xFF1B5E20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          await assistantPerformAction(
                            context,
                            ref,
                            action,
                            onSendMessage: (msg) => ref
                                .read(assistantChatProvider.notifier)
                                .sendUserMessage(msg),
                          );
                          onNavigate?.call();
                        },
                        child: Text(action.label),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF2E7D32),
            ),
          ),
          SizedBox(width: 12),
          Text(
            '正在查詢您的資料…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
