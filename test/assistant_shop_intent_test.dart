import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/domain/assistant_shop_intent.dart';

const _shopCorpus = <(String, AssistantShopIntent)>[
  ('我要買米和醬油', AssistantShopIntent.recordDemand),
  ('買兩瓶牛奶', AssistantShopIntent.recordDemand),
  ('雞蛋多少錢', AssistantShopIntent.queryPrice),
  ('醬油價格', AssistantShopIntent.queryPrice),
  ('我剛剛說要買什麼', AssistantShopIntent.viewRecorded),
  ('買了什麼', AssistantShopIntent.viewRecorded),
  ('那個牛奶不要了', AssistantShopIntent.cancelDemand),
  ('取消麵包', AssistantShopIntent.cancelDemand),
  ('你好', AssistantShopIntent.casual),
  ('最近好嗎', AssistantShopIntent.casual),
  ('幫我買高麗菜', AssistantShopIntent.recordDemand),
  ('白米多少錢', AssistantShopIntent.queryPrice),
  ('記錄什麼', AssistantShopIntent.viewRecorded),
  ('不要了', AssistantShopIntent.cancelDemand),
  ('早安', AssistantShopIntent.casual),
  ('採買衛生紙', AssistantShopIntent.recordDemand),
  ('想買香蕉', AssistantShopIntent.recordDemand),
  ('衛生紙賣多少', AssistantShopIntent.queryPrice),
  ('查價格', AssistantShopIntent.queryPrice),
  ('我記了什麼', AssistantShopIntent.viewRecorded),
  ('需求單列表', AssistantShopIntent.viewRecorded),
  ('牛奶不用買', AssistantShopIntent.cancelDemand),
  ('刪掉高麗菜', AssistantShopIntent.cancelDemand),
  ('陪我聊天', AssistantShopIntent.casual),
  ('謝謝', AssistantShopIntent.casual),
];

void main() {
  test('第五章五類意圖準確率 ≥90%', () {
    var ok = 0;
    final miss = <String>[];
    for (final s in _shopCorpus) {
      final got = AssistantShopIntentClassifier.classify(s.$1);
      if (got.intent == s.$2) {
        ok++;
      } else {
        miss.add('${s.$1} 期望${s.$2.name} 得${got.intent.name}(${got.layer})');
      }
    }
    final acc = ok / _shopCorpus.length;
    expect(acc, greaterThanOrEqualTo(0.9), reason: miss.join('\n'));
  });

  test('記錄需求會解析槽位', () {
    final r = AssistantShopIntentClassifier.classify('我要買米和醬油');
    expect(r.intent, AssistantShopIntent.recordDemand);
    expect(r.slots?.lines.length, greaterThanOrEqualTo(1));
  });
}
