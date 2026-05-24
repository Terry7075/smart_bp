import 'package:smart_bp/features/assistant/domain/assistant_message.dart';

/// 多輪對話中「那代購呢」「上一筆」等追問的語境解析。
abstract final class AssistantDialogContext {
  /// 若為追問且可從近期對話推斷主題，回傳展開後的查詢句；否則回傳原文。
  static String resolve({
    required String question,
    required List<AssistantMessage> conversation,
  }) {
    final n = _norm(question);
    if (n.isEmpty || !_isFollowUp(n)) return question;

    final topic = _topicFromHistory(conversation);
    if (topic == null) return question;

    return _expand(topic, question, n);
  }

  static String _norm(String q) =>
      q.trim().toLowerCase().replaceAll(' ', '');

  static bool _contains(String n, List<String> keys) {
    for (final k in keys) {
      if (n.contains(k)) return true;
    }
    return false;
  }

  static bool _isFollowUp(String n) {
    const explicit = [
      '那代購', '代購呢', '訂單呢', '需求單呢', '配送呢', '送達呢',
      '那藥單', '藥單呢', '那訂單', '上一筆', '上一單', '剛才那', '剛剛那',
      '再查一次', '再說一次', '再幫我查',
    ];
    if (_contains(n, explicit)) return true;

    const shortMarkers = ['那', '再', '還有', '呢', '然後', '繼續', '再說'];
    final hasMarker = _contains(n, shortMarkers);
    if (!hasMarker) return false;

    const domain = [
      '代購', '訂單', '需求單', '配送', '柑仔店', '商店', '買',
      '藥單', '處方', '藥', '志工', '掃描', '健康',
      '交通', '學習', '活動', '首頁', '個人', '功能', '怎麼', '如何', '在哪',
    ];
    if (_contains(n, domain)) return true;

    return n.length <= 12;
  }

  static _DialogTopic? _topicFromHistory(List<AssistantMessage> conversation) {
    for (var i = conversation.length - 1; i >= 0; i--) {
      final t = _topicFromText(conversation[i].text);
      if (t != null) return t;
    }
    return null;
  }

  static _DialogTopic? _topicFromText(String text) {
    final n = _norm(text);
    if (n.isEmpty) return null;

    if (_contains(n, ['代購', '訂單', '需求單', '配送', '採買', '送達', '柑仔店物資'])) {
      return _DialogTopic.shop;
    }
    if (_contains(n, ['藥單', '處方', '吃藥', '提醒', '掃描', 'ocr', '志工確認'])) {
      return _DialogTopic.prescription;
    }
    if (_contains(n, ['怎麼用', '如何', '在哪', '帶我', '前往', '教學', '導覽'])) {
      return _DialogTopic.appGuide;
    }
    if (_contains(n, ['柑仔店', '商店', '買東西']) &&
        !_contains(n, ['進度', '狀態', '到哪', '好了嗎'])) {
      return _DialogTopic.appGuide;
    }
    return null;
  }

  static String _expand(_DialogTopic topic, String original, String n) {
    switch (topic) {
      case _DialogTopic.shop:
        if (_contains(n, ['代購', '訂單', '需求單', '配送', '送達', '採買', '進度', '狀態'])) {
          return original;
        }
        return '代購訂單進度';
      case _DialogTopic.prescription:
        if (_contains(n, ['藥單', '處方', '藥', '志工', '掃描', '吃藥', '提醒'])) {
          return original;
        }
        return '我的藥單怎麼了';
      case _DialogTopic.appGuide:
        if (_contains(n, ['怎麼', '如何', '在哪', '哪裡', '帶我', '前往'])) {
          return original;
        }
        return '怎麼用柑仔店';
    }
  }
}

enum _DialogTopic { shop, prescription, appGuide }
