import 'package:flutter/material.dart';

/// 小幫手畫面上的長輩友善提示文案（集中維護）。
abstract final class AssistantHints {
  static const welcomeMessage = '''
嗨，我是明德小幫手～

代購請到「柑仔店」填寫物資需求並送出給志工。
這裡可以協助您：語音快速輸入、查詢進度、查參考價格、帶路找功能。''';

  /// 輸入框灰色提示（較短，避免擠滿）。
  static const inputHint = '打字或按左側麥克風說話';

  static const voiceHint = '按麥克風說話，字幕會即時顯示';

  static const helpPanelTitle = '常見問題';

  static const helpPanelSubtitle = '點一下，小幫手立刻幫您查';

  static const helpPanelFootnote =
      '代購、藥單、帶路都能問；閒聊也有雲端輔助。';

  /// 點擊後直接送出當作使用者問題（扁平清單，供相容舊邏輯）。
  static List<String> get sampleQuestions =>
      faqGroups.expand((g) => g.questions).toList();

  static const faqGroups = [
    AssistantFaqGroup(
      label: '日常問候',
      icon: Icons.waving_hand_rounded,
      accent: Color(0xFF1565C0),
      questions: ['最近好嗎？'],
    ),
    AssistantFaqGroup(
      label: '代購物資',
      icon: Icons.shopping_basket_outlined,
      accent: Color(0xFFE65100),
      questions: [
        '我家衛生紙沒了',
        '代購到哪了？',
        '怎麼用柑仔店？',
      ],
    ),
    AssistantFaqGroup(
      label: '藥單健康',
      icon: Icons.medication_outlined,
      accent: Color(0xFF6A1B9A),
      questions: [
        '我的藥單怎麼了？',
        '健康掃描怎麼用？',
        '吃藥提醒怎麼設定？',
      ],
    ),
    AssistantFaqGroup(
      label: '功能帶路',
      icon: Icons.explore_outlined,
      accent: Color(0xFF2E7D32),
      questions: [
        '全部功能',
        '交通在哪？',
        '個人資料在哪？',
      ],
    ),
  ];

  static const capabilities = [
    AssistantCapability(
      icon: Icons.chat_bubble_outline,
      title: '輕鬆聊',
      subtitle: '問候、閒聊，雲端也能陪您說話',
      accent: Color(0xFF1565C0),
    ),
    AssistantCapability(
      icon: Icons.explore_outlined,
      title: '帶路',
      subtitle: '不會用就說，我帶您過去',
      accent: Color(0xFF2E7D32),
    ),
    AssistantCapability(
      icon: Icons.medication_outlined,
      title: '查藥單',
      subtitle: '自動看系統裡的進度',
      accent: Color(0xFF6A1B9A),
    ),
    AssistantCapability(
      icon: Icons.storefront_outlined,
      title: '協助填寫',
      subtitle: '語音記入採買清單，送出請到柑仔店',
      accent: Color(0xFFE65100),
    ),
  ];
}

class AssistantFaqGroup {
  const AssistantFaqGroup({
    required this.label,
    required this.icon,
    required this.accent,
    required this.questions,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final List<String> questions;
}

class AssistantCapability {
  const AssistantCapability({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
}
