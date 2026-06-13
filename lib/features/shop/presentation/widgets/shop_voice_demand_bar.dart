import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_supply_dialogue_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_elder_ui.dart';

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
    final listening = voice.isListening;

    return Card(
      color: const Color(0xFFEFEBE9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            const Text(
              '語音輸入',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (listening) ...[
              const SizedBox(height: 8),
              Text(
                '正在聽：${voice.liveText.isEmpty ? "…" : voice.liveText}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, height: 1.4),
              ),
            ],
            const SizedBox(height: 18),
            Listener(
              onPointerDown: (_) async {
                await ref.read(assistantVoiceProvider.notifier).ensureInitialized();
                if (!voice.isListening) {
                  await ref.read(assistantVoiceProvider.notifier).toggleListening();
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
              child: Material(
                color: listening ? const Color(0xFFC62828) : ShopElderUi.brown,
                shape: const CircleBorder(),
                elevation: 6,
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        listening ? Icons.mic : Icons.mic_none,
                        size: 44,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listening ? '放開' : '按住',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (listening) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    ref.read(assistantVoiceProvider.notifier).cancelListening(),
                icon: const Icon(Icons.close),
                label: const Text('取消', style: TextStyle(fontSize: 18)),
              ),
            ],
            if (dialogue.busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: ShopElderUi.brown),
            ],
          ],
        ),
      ),
    );
  }
}
