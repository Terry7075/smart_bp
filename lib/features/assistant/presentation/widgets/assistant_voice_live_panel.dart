import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';

/// 語音聆聽時的即時字幕面板（含動畫）。
class AssistantVoiceLivePanel extends ConsumerStatefulWidget {
  const AssistantVoiceLivePanel({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  ConsumerState<AssistantVoiceLivePanel> createState() =>
      _AssistantVoiceLivePanelState();
}

class _AssistantVoiceLivePanelState extends ConsumerState<AssistantVoiceLivePanel>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(assistantVoiceProvider);
  final text = voice.liveText.trim().isEmpty ? '…' : voice.liveText;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE8F5E9),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E7D32), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _PulsingMic(pulse: _pulse),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '正在聽您說話…',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                _SoundBars(level: voice.soundLevel),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Container(
                key: ValueKey<String>(text),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: text == '…'
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _cursor,
                      child: Container(
                        width: 3,
                        height: 28,
                        margin: const EdgeInsets.only(left: 4, bottom: 4),
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '說完後按「說完了送出」；字幕會隨您說話即時更新',
              style: TextStyle(fontSize: 15, color: Color(0xFF5D4037)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: widget.onConfirm,
                    icon: const Icon(Icons.check_circle_outline, size: 26),
                    label: const Text(
                      '說完了送出',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingMic extends StatelessWidget {
  const _PulsingMic({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = 1.0 + pulse.value * 0.12;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(
                alpha: 0.15 + pulse.value * 0.2,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              color: Color(0xFFC62828),
              size: 32,
            ),
          ),
        );
      },
    );
  }
}

class _SoundBars extends StatelessWidget {
  const _SoundBars({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final n = level.clamp(0, 10) / 10;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final h = 8.0 + (n * 28 * ((i % 3) + 1) / 3);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(left: 3),
          width: 5,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
