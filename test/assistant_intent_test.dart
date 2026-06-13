import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/assistant/data/assistant_intent.dart';

import 'assistant_intent_corpus.dart';

void main() {
  group('AssistantIntent.classify', () {
    test('閒聊不被判成查資料', () {
      expect(AssistantIntent.classify('最近好嗎'), AssistantQueryKind.casual);
      expect(AssistantIntent.classify('謝謝你'), AssistantQueryKind.casual);
    });

    test('代購進度為 systemData', () {
      expect(AssistantIntent.classify('代購到哪了'), AssistantQueryKind.systemData);
      expect(AssistantIntent.classify('我的訂單怎麼了'), AssistantQueryKind.systemData);
      expect(AssistantIntent.classify('配送進度'), AssistantQueryKind.systemData);
    });

    test('柑仔店教學為 appGuide', () {
      expect(AssistantIntent.classify('怎麼用柑仔店'), AssistantQueryKind.appGuide);
      expect(AssistantIntent.classify('柑仔店在哪'), AssistantQueryKind.appGuide);
    });
  });

  test('意圖分類準確率（擴充語料 ≥80%）', () {
    var correct = 0;
    final confusion = <String, int>{};
    for (final s in assistantIntentCorpus) {
      final got = AssistantIntent.classify(s.$1);
      if (got == s.$2) {
        correct++;
      } else {
        final key = '${s.$2.name}→${got.name}:${s.$1}';
        confusion[key] = (confusion[key] ?? 0) + 1;
      }
    }
    final accuracy = correct / assistantIntentCorpus.length;
    expect(
      accuracy,
      greaterThanOrEqualTo(0.8),
      reason: 'misclassified: $confusion',
    );
  });
}
