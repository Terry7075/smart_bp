/// 使用者想問什麼（小幫手自行判斷，再決定要不要查系統資料）。
enum AssistantQueryKind {
  /// 藥單、代購、吃藥提醒等——需讀 [AssistantSnapshot]。
  systemData,

  /// App 怎麼用、去哪一頁——帶路與教學。
  appGuide,

  /// 陪聊、問候、情緒、閒話。
  casual,
}

/// 判斷使用者訊息意圖（閒聊優先，避免「最近好嗎」被當成查資料）。
abstract final class AssistantIntent {
  static AssistantQueryKind classify(String question) {
    final n = _norm(question);
    if (n.isEmpty) return AssistantQueryKind.casual;

    if (_isClearlyCasual(n)) return AssistantQueryKind.casual;
    if (_isSystemData(n)) return AssistantQueryKind.systemData;
    if (_isAppGuide(n)) return AssistantQueryKind.appGuide;

    return AssistantQueryKind.casual;
  }

  @Deprecated('Use classify()')
  static bool isAppRelated(String question) {
    final k = classify(question);
    return k == AssistantQueryKind.systemData ||
        k == AssistantQueryKind.appGuide;
  }

  static String _norm(String q) =>
      q.trim().toLowerCase().replaceAll(' ', '');

  static bool _contains(String n, List<String> keys) {
    for (final k in keys) {
      if (n.contains(k)) return true;
    }
    return false;
  }

  static bool _isClearlyCasual(String n) {
    const mood = [
      '最近好嗎', '好嗎', '怎麼樣', '過得好', '還好嗎', '心情', '無聊', '寂寞',
      '孤單', '閒聊', '聊天', '陪聊', '謝謝', '感謝', '辛苦了', '再見', '拜拜',
      '難過', '傷心', '委屈', '生氣', '煩', '累', '疲憊', '好睏', '睡不著',
      '真棒', '好用', '先這樣', '下線',
    ];
    if (_contains(n, mood)) return true;

    const weatherEtc = ['天氣', '新聞', '股票', '政治'];
    if (_contains(n, weatherEtc)) return true;

    const greet = ['你好', '嗨', '哈囉', '早安', '午安', '晚安'];
    final onlyGreeting = greet.any(n.contains) &&
        !_contains(n, [
          '藥單', '處方', '代購', '訂單', '柑仔店', '健康', '掃描', '功能',
          '在哪', '怎麼', '如何', '進度', '狀態',
        ]);
    if (onlyGreeting) return true;

    return false;
  }

  static bool _isSystemData(String n) {
    const dataKeys = [
      '藥單', '處方', '代購', '訂單', '需求單', '志工', '掃描', 'ocr',
      '吃藥', '提醒', '打卡', '鬧鐘',
    ];
    if (_contains(n, dataKeys)) return true;

    if (n.contains('藥') &&
        _contains(n, ['怎麼', '進度', '狀態', '處理', '好了嗎', '怎樣', '查'])) {
      return true;
    }

    if (_contains(n, ['代購', '訂單', '柑仔店', '商店']) &&
        _contains(n, ['哪', '進度', '狀態', '怎麼', '查', '好了嗎'])) {
      return true;
    }

    if (_contains(n, ['到哪', '怎麼了', '查一下', '幫我查', '幫我看'])) {
      return true;
    }

    return false;
  }

  static bool _isAppGuide(String n) {
    const guideKeys = [
      '怎麼', '如何', '在哪', '哪裡', '哪一', '帶我', '帶您', '前往', '打開',
      '全部', '所有', '功能', '導覽', '教學', '地圖', '不會用', '教我',
    ];
    if (_contains(n, guideKeys)) return true;

    const pages = [
      '首頁', '主畫面', '主頁', '交通', '公車', '接駁', '巴士',
      '學習', '課程', '講座', '報名', '活動', '共餐', '聚會',
      '個人', '資料', '帳號', '登出', '頭像', '柑仔店', '商店', '買東西',
      '健康', '小幫手', 'app', '明德', '達人',
    ];
    if (_contains(n, pages)) return true;

    if (_contains(n, ['可以做', '能做', '幫我', '幫忙'])) return true;

    return false;
  }
}
