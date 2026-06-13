import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/assistant/data/assistant_dialog_context.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';

void main() {
  group('AssistantDialogContext.resolve', () {
    test('追問代購會展開為查進度', () {
      final convo = [
        AssistantMessage(
          role: AssistantMessageRole.user,
          text: '代購到哪了',
          at: DateTime(2026, 1, 1),
        ),
        AssistantMessage(
          role: AssistantMessageRole.assistant,
          text: '最近代購狀態：處理中',
          at: DateTime(2026, 1, 1),
        ),
      ];
      expect(
        AssistantDialogContext.resolve(question: '那呢', conversation: convo),
        '代購訂單進度',
      );
    });

    test('非追問句不修改', () {
      expect(
        AssistantDialogContext.resolve(question: '你好', conversation: const []),
        '你好',
      );
    });
  });
}
