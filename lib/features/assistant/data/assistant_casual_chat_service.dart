import 'dart:math';

import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';

/// 陪聊／日常對話（多句、多變化，非制式單一模板）。
class AssistantCasualChatService {
  final _rng = Random();

  AssistantReply reply({
    required String question,
    required AssistantSnapshot snapshot,
    required List<AssistantMessage> conversation,
  }) {
    final n = question.trim().toLowerCase().replaceAll(' ', '');
    final name = (snapshot.displayName ?? '').trim();
    final who = name.isNotEmpty ? name : '您';
    final recent = _recentAssistantTexts(conversation);

    String text;
    if (_any(n, ['謝謝', '感謝', '辛苦了', '真棒', '好用'])) {
      text = _pick([
        '不客氣，$who！能幫上忙我很開心。\n有代購或藥單的事隨時問我。',
        '別客氣～$who 願意用這個 App，我們也很高興。\n今天還想查什麼嗎？',
        '謝謝 $who！若還有不會的操作，跟我說一聲就好。',
      ], recent);
    } else if (_any(n, ['再見', '拜拜', '晚安', '先這樣', '下線'])) {
      text = _pick([
        '好的，$who 保重！需要時再來找小幫手。\n祝您今天順順的。',
        '拜拜～$who 記得按時吃藥、有需要再回來聊。',
        '晚安，$who！祝您睡個好覺。',
      ], recent);
    } else if (_any(n, ['無聊', '寂寞', '孤單', '沒事', '閒聊', '聊天'])) {
      text = _pick([
        '我在這陪 $who 聊兩句呀。\n'
            '最近社區活動或柑仔店有沒有想買的？我可以幫您查代購進度。',
        '$who 若悶了，可以到首頁看看活動或學習分頁。\n'
            '想說說話也可以，我會簡短回您。',
        '陪您聊沒問題～\n'
            '順便問，藥單或代購有需要我幫忙看的嗎？',
      ], recent);
    } else if (_any(n, ['難過', '傷心', '委屈', '生氣', '煩'])) {
      text = _pick([
        '$who 辛苦了。願您慢慢好起來。\n'
            '若身體不舒服，還是要找醫師或藥師喔。',
        '聽起來不容易，$who 先深呼吸一下。\n'
            '需要查 App 裡的事，我隨時在。',
        '我懂 $who 心情可能不太好。\n'
            '陪您聊幾句可以，嚴重的話記得找家人或醫師。',
      ], recent);
    } else if (_any(n, ['累', '疲憊', '好睏', '睡不著'])) {
      text = _pick([
        '$who 要多休息呀，身體最重要。\n'
            '吃藥提醒有開的話，記得照時間來。',
        '累了就歇一會兒，別硬撐。\n'
            '有代購或藥單問題，等您精神好點再問我也行。',
      ], recent);
    } else if (_any(n, [
      '天氣', '下雨', '降雨', '氣溫', '溫度', '颱風',
      '新聞', '股票', '政治', '總統',
    ])) {
      text = _pick([
        '$who，這題我這邊暫時連不上雲端。\n'
            '請確認有網路後再問；代購、藥單我仍可幫您查。',
        '雲端暫時沒回應，天氣這類問題請稍後再試。\n'
            'App 裡的事隨時問我。',
      ], recent);
    } else if (_any(n, ['你好', '嗨', '哈囉', '早安', '午安'])) {
      text = _pick([
        '${_timeGreeting()}$who！\n'
            '想聊天或查藥單、代購都可以跟我說。',
        '嗨，$who～今天過得如何？\n'
            '有 App 不會用也能問我。',
      ], recent);
    } else {
      text = _pick([
        '好呀，$who，我在這陪您聊。\n'
            '也可以問「代購到哪」或「藥單怎麼了」。',
        '$who 想聊什麼都可以說。\n'
            '需要帶您去柑仔店、健康分頁，跟我說一聲就行。',
        '我主要在這邊陪 $who，也幫忙查明德 App 的事。\n'
            '有具體問題時，用簡單一句話問我就好。',
      ], recent);
    }

    return AssistantReply(text: text);
  }

  bool _any(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  String _pick(List<String> options, Set<String> recent) {
    if (options.isEmpty) return '';
    final fresh = options.where((o) => !recent.contains(o)).toList();
    final pool = fresh.isNotEmpty ? fresh : options;
    return pool[_rng.nextInt(pool.length)];
  }

  Set<String> _recentAssistantTexts(List<AssistantMessage> conversation) {
    return conversation
        .where((m) => m.isAssistant)
        .map((m) => m.text)
        .toSet();
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return '早安，';
    if (h < 17) return '午安，';
    if (h < 21) return '您好，';
    return '晚安，';
  }
}
