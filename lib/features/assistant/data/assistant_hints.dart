/// 小幫手畫面上的長輩友善提示文案（集中維護）。
abstract final class AssistantHints {
  static const welcomeMessage = '''
嗨，我是明德小幫手～

跟我聊天、問藥單代購、不會用 App 都可以，我會用輕鬆的話回您；
要是跟系統有關，我會自動幫您查清楚。''';

  /// 輸入框灰色提示（較短，避免擠滿）。
  static const inputHint = '打字或按左側麥克風說話';

  static const voiceHint = '按麥克風說話，字幕會即時顯示';

  static const helpPanelTitle = '常見問題（點一下就會問）';

  static const helpPanelFootnote =
      '同一個小幫手：閒聊、查資料、帶路都行；'
      '天氣、新聞我查不到喔。';

  /// 點擊後直接送出當作使用者問題。
  static const sampleQuestions = [
    '最近好嗎？',
    '全部功能',
    '我的藥單怎麼了？',
    '代購到哪了？',
    '怎麼用柑仔店？',
    '健康掃描怎麼用？',
    '吃藥提醒怎麼設定？',
    '交通在哪？',
    '個人資料在哪？',
  ];

  static const capabilities = [
    _Capability(
      icon: '💬',
      title: '輕鬆聊',
      subtitle: '問候、閒聊，像鄰居說話',
    ),
    _Capability(
      icon: '🧭',
      title: '帶路',
      subtitle: '不會用就說，我帶您過去',
    ),
    _Capability(
      icon: '💊',
      title: '查藥單',
      subtitle: '自動看系統裡的進度',
    ),
    _Capability(
      icon: '🛒',
      title: '查代購',
      subtitle: '代購到哪一步，幫您看',
    ),
  ];
}

class _Capability {
  const _Capability({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;
}
