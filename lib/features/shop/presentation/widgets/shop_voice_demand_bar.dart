import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_demand_input_page.dart';

/// 語音輸入 → 三層意圖 → 寫入 demand_records；支援按住說話（報告 5.3.1）。
class ShopVoiceDemandBar extends ConsumerStatefulWidget {
  const ShopVoiceDemandBar({
    super.key,
    this.autoApplyOnRelease = false,
  });

  /// 放開麥克風後自動解析並加入需求單（需求輸入頁為 true）。
  final bool autoApplyOnRelease;

  @override
  ConsumerState<ShopVoiceDemandBar> createState() => _ShopVoiceDemandBarState();
}

class _ShopVoiceDemandBarState extends ConsumerState<ShopVoiceDemandBar> {
  static const Color _brown = Color(0xFF5D4037);

  Future<void> _applyVoice(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }

    final classification = AssistantShopIntentClassifier.classify(text);
    if (classification.intent == AssistantShopIntent.casual &&
        (classification.slots == null || classification.slots!.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請說要買的商品，例如「我要買雞蛋和牛奶」'),
        ),
      );
      return;
    }

    final reply = await ref.read(assistantShopActionServiceProvider).handle(
          classification: classification,
          userId: uid,
          snapshot: const AssistantSnapshot(),
        );

    ref.invalidate(elderDemandDraftProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reply.text.split('\n').first,
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(assistantVoiceProvider);

    return Card(
      color: const Color(0xFFEFEBE9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '語音記錄需求',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              voice.isListening
                  ? '正在聽：${voice.liveText.isEmpty ? "…" : voice.liveText}'
                  : '按住麥克風說「我要買米和醬油」，放開即記入需求',
              style: const TextStyle(fontSize: 16, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Listener(
                    onPointerDown: (_) async {
                      await ref
                          .read(assistantVoiceProvider.notifier)
                          .ensureInitialized();
                      if (!voice.isListening) {
                        await ref
                            .read(assistantVoiceProvider.notifier)
                            .toggleListening();
                      }
                    },
                    onPointerUp: (_) async {
                      if (!voice.isListening) return;
                      final text = await ref
                          .read(assistantVoiceProvider.notifier)
                          .finishListening();
                      if (widget.autoApplyOnRelease) {
                        await _applyVoice(text ?? voice.liveText);
                      }
                    },
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: Icon(
                        voice.isListening ? Icons.mic : Icons.mic_none,
                        size: 28,
                      ),
                      label: Text(
                        voice.isListening ? '放開即完成' : '按住說話',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brown,
                        disabledBackgroundColor: _brown,
                        disabledForegroundColor: Colors.white,
                        minimumSize: const Size(0, 56),
                      ),
                    ),
                  ),
                ),
                if (!widget.autoApplyOnRelease) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: voice.isListening || voice.liveText.trim().isNotEmpty
                        ? () async {
                            final text = await ref
                                .read(assistantVoiceProvider.notifier)
                                .finishListening();
                            if (!mounted) return;
                            await _applyVoice(text ?? voice.liveText);
                          }
                        : null,
                    icon: const Icon(Icons.check, size: 28),
                    tooltip: '完成並解析',
                  ),
                ],
                if (voice.isListening)
                  IconButton(
                    onPressed: () => ref
                        .read(assistantVoiceProvider.notifier)
                        .cancelListening(),
                    icon: const Icon(Icons.close, size: 28),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
