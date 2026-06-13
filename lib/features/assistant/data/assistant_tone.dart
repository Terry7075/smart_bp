import 'dart:math';

import 'package:smart_bp/features/assistant/data/assistant_intent.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 把規則引擎的精準內容，包成輕鬆口語（同一個小幫手口吻）。
abstract final class AssistantTone {
  static final _rng = Random();

  static AssistantReply warmify(
    AssistantReply reply, {
    required AssistantQueryKind kind,
    required AssistantSnapshot snapshot,
    required String question,
  }) {
    final who = _who(snapshot);
    final opener = _opener(kind, who);
    final closer = _closer(reply.actions.isNotEmpty);

    var body = reply.text.trim();
    body = _soften(body);

    final text = [opener, body, closer]
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');

    return AssistantReply(text: text, actions: reply.actions);
  }

  static String _who(AssistantSnapshot s) {
    final name = (s.displayName ?? '').trim();
    return name.isNotEmpty ? name : '您';
  }

  static String _opener(AssistantQueryKind kind, String who) {
    final List<String> pool = switch (kind) {
      AssistantQueryKind.systemData => [
        '好，$who，我幫您看過系統裡的資料囉～',
        '嗯嗯，查到了，跟您說一下～',
        '好呀 $who，這邊是您的狀況：',
      ],
      AssistantQueryKind.appGuide => [
        '沒問題！$who 我簡單跟您說～',
        '好呀，這樣操作就行：',
        '了解，帶您用 App 很簡單：',
      ],
      AssistantQueryKind.casual => <String>[],
    };
    if (pool.isEmpty) return '';
    return pool[_rng.nextInt(pool.length)];
  }

  static String _closer(bool hasNav) {
    if (!hasNav) {
      return _pick([
        '還想聊或要查別的，隨時跟我說。',
        '有別的想問，直接打字就好。',
      ]);
    }
    return _pick([
      '要過去的話，點下面按鈕就行。',
      '需要我帶您過去，按下面「前往」就可以。',
    ]);
  }

  static String _soften(String text) {
    return text
        .replaceAll('請點底部', '點一下底部')
        .replaceAll('請點', '點一下')
        .replaceAll('請用', '用')
        .replaceAll('請先', '先')
        .replaceAll('請確認', '記得確認');
  }

  static String _pick(List<String> options) =>
      options[_rng.nextInt(options.length)];
}
