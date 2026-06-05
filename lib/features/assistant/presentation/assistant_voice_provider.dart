import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 小幫手語音輸入狀態（即時字幕）。
class AssistantVoiceState {
  const AssistantVoiceState({
    this.available = false,
    this.isListening = false,
    this.liveText = '',
    this.soundLevel = 0,
    this.errorMessage,
  });

  final bool available;
  final bool isListening;
  final String liveText;
  final double soundLevel;
  final String? errorMessage;

  AssistantVoiceState copyWith({
    bool? available,
    bool? isListening,
    String? liveText,
    double? soundLevel,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AssistantVoiceState(
      available: available ?? this.available,
      isListening: isListening ?? this.isListening,
      liveText: liveText ?? this.liveText,
      soundLevel: soundLevel ?? this.soundLevel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AssistantVoiceInput extends Notifier<AssistantVoiceState> {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  @override
  AssistantVoiceState build() => const AssistantVoiceState();

  Future<bool> ensureInitialized() async {
    if (_initialized) return state.available;
    try {
      final ok = await _speech.initialize(
        onStatus: _onStatus,
        onError: (e) {
          state = state.copyWith(
            errorMessage: e.errorMsg,
            isListening: false,
          );
        },
        debugLogging: kDebugMode,
      );
      _initialized = true;
      state = state.copyWith(available: ok, clearError: true);
      return ok;
    } catch (e) {
      _initialized = true;
      state = state.copyWith(
        available: false,
        errorMessage: '此裝置無法使用語音輸入',
      );
      return false;
    }
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (state.isListening) {
        state = state.copyWith(isListening: false);
      }
    }
  }

  /// 開始／結束語音聆聽（toggle）。
  Future<String?> toggleListening() async {
    if (!_initialized) {
      final ok = await ensureInitialized();
      if (!ok) return null;
    }
    if (!_speech.isAvailable) {
      state = state.copyWith(
        errorMessage: '語音辨識不可用，請改用打字或確認已允許麥克風',
      );
      return null;
    }

    if (state.isListening) {
      await _speech.stop();
      state = state.copyWith(isListening: false);
      return state.liveText.trim().isEmpty ? null : state.liveText.trim();
    }

    state = state.copyWith(
      isListening: true,
      liveText: '',
      soundLevel: 0,
      clearError: true,
    );

    final locale = await _pickChineseLocale();
    await _speech.listen(
      onResult: (result) {
        state = state.copyWith(
          liveText: result.recognizedWords,
        );
      },
      localeId: locale,
      // 高齡使用者停頓較長：延長靜音判定，降低句中截斷（報告 5.2.3）。
      pauseFor: const Duration(milliseconds: 3500),
      listenFor: const Duration(seconds: 60),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
      onSoundLevelChange: (level) {
        if (state.isListening) {
          state = state.copyWith(soundLevel: level);
        }
      },
    );
    return null;
  }

  Future<void> cancelListening() async {
    if (state.isListening) {
      await _speech.stop();
    }
    state = state.copyWith(
      isListening: false,
      liveText: '',
      soundLevel: 0,
      clearError: true,
    );
  }

  /// 結束聆聽並回傳辨識文字。
  Future<String?> finishListening() async {
    if (!state.isListening) {
      final t = state.liveText.trim();
      return t.isEmpty ? null : t;
    }
    await _speech.stop();
    final text = state.liveText.trim();
    state = state.copyWith(isListening: false, soundLevel: 0);
    return text.isEmpty ? null : text;
  }

  Future<String?> _pickChineseLocale() async {
    final locales = await _speech.locales();
    const preferred = ['zh-TW', 'zh_TW', 'zh-Hant', 'zh-HK', 'zh-CN', 'zh'];
    for (final p in preferred) {
      for (final l in locales) {
        if (l.localeId == p) return l.localeId;
      }
    }
    for (final l in locales) {
      if (l.localeId.startsWith('zh')) return l.localeId;
    }
    return locales.isNotEmpty ? locales.first.localeId : null;
  }
}

final assistantVoiceProvider =
    NotifierProvider<AssistantVoiceInput, AssistantVoiceState>(
  AssistantVoiceInput.new,
);
