import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_mode.dart';

export 'package:smart_bp/features/assistant/domain/assistant_chat_mode.dart';

final assistantChatModeProvider =
    NotifierProvider<AssistantChatModeNotifier, AssistantChatMode>(
  AssistantChatModeNotifier.new,
);

class AssistantChatModeNotifier extends Notifier<AssistantChatMode> {
  static const _prefsKey = 'assistant_chat_mode_v1';

  @override
  AssistantChatMode build() {
    Future.microtask(_normalizeSavedMode);
    return AssistantChatMode.smart;
  }

  /// 舊版若存了陪聊模式，一律改回統一智慧模式。
  Future<void> _normalizeSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != 'smart') {
      await prefs.setString(_prefsKey, 'smart');
    }
  }
}
