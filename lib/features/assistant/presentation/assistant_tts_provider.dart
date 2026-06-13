import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 狀態與互斥控制（語音收音時自動停止播報）。
class AssistantTtsState {
  const AssistantTtsState({
    this.enabled = true,
    this.speaking = false,
    this.speechRate = 0.45,
  });

  /// 使用者是否啟用自動播報（可在設定或頁面切換）。
  final bool enabled;

  /// 是否正在播放中。
  final bool speaking;

  /// 語速（0.0–1.0，長輩友善預設 0.45）。
  final double speechRate;

  AssistantTtsState copyWith({bool? enabled, bool? speaking, double? speechRate}) =>
      AssistantTtsState(
        enabled: enabled ?? this.enabled,
        speaking: speaking ?? this.speaking,
        speechRate: speechRate ?? this.speechRate,
      );
}

class AssistantTtsNotifier extends Notifier<AssistantTtsState> {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  @override
  AssistantTtsState build() {
    ref.onDispose(() => _tts.stop());
    return const AssistantTtsState();
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('zh-TW');
      await _tts.setSpeechRate(state.speechRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        state = state.copyWith(speaking: false);
      });
      _tts.setErrorHandler((msg) {
        state = state.copyWith(speaking: false);
        if (kDebugMode) debugPrint('[TTS] error: $msg');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] init error: $e');
    }
  }

  /// 播報文字（Web 不支援時靜默失敗）。
  /// [forceSpeak] 為 true 時忽略 `enabled` 開關（例如手動按重播）。
  Future<void> speak(String text, {bool forceSpeak = false}) async {
    if (kIsWeb) return; // flutter_tts 在 Web 支援有限，不強制
    if (!forceSpeak && !state.enabled) return;
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.setSpeechRate(state.speechRate);
    await _tts.stop();
    state = state.copyWith(speaking: true);
    try {
      await _tts.speak(text.trim());
    } catch (e) {
      state = state.copyWith(speaking: false);
      if (kDebugMode) debugPrint('[TTS] speak error: $e');
    }
  }

  /// 停止播報（語音收音開始時必須呼叫）。
  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts.stop();
    } catch (_) {}
    state = state.copyWith(speaking: false);
  }

  void toggleEnabled() => state = state.copyWith(enabled: !state.enabled);

  void setSpeechRate(double rate) {
    state = state.copyWith(speechRate: rate.clamp(0.1, 1.0));
  }
}

final assistantTtsProvider =
    NotifierProvider<AssistantTtsNotifier, AssistantTtsState>(
  AssistantTtsNotifier.new,
);
