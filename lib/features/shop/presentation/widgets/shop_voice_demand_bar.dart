import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_supply_dialogue_provider.dart';

/// 語音輸入 → 品類辨識 → 品牌確認（不直接送出志工）。
class ShopVoiceDemandBar extends ConsumerStatefulWidget {
  const ShopVoiceDemandBar({
    super.key,
    this.autoApplyOnRelease = false,
  });

  final bool autoApplyOnRelease;

  @override
  ConsumerState<ShopVoiceDemandBar> createState() => _ShopVoiceDemandBarState();
}

class _ShopVoiceDemandBarState extends ConsumerState<ShopVoiceDemandBar> {
  static const Color _brown = Color(0xFF5D4037);

  Future<void> _applyVoice(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    final err =
        await ref.read(shopSupplyDialogueProvider.notifier).handleUtterance(text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(assistantVoiceProvider);
    final dialogue = ref.watch(shopSupplyDialogueProvider);

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
                  : '按住麥克風說「我要衛生紙兩包」，放開後會請您選品牌',
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
                    onPressed: voice.isListening ||
                            voice.liveText.trim().isNotEmpty
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
            if (dialogue.busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: _brown),
              ),
          ],
        ),
      ),
    );
  }
}
