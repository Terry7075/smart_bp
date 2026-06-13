import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';

/// 側邊欄用：依日期分組的歷史對話。
class AssistantHistoryDateGroup {
  const AssistantHistoryDateGroup({
    required this.label,
    required this.sessions,
  });

  final String label;
  final List<AssistantChatSession> sessions;
}

/// 將對話依 `updatedAt` 的本地日期分組（今天、昨天、其他日期）。
List<AssistantHistoryDateGroup> groupSessionsByDate(
  List<AssistantChatSession> sessions,
) {
  if (sessions.isEmpty) return [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final buckets = <String, List<AssistantChatSession>>{};
  final order = <String>[];

  for (final s in sessions) {
    final local = s.updatedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final label = _dayLabel(day, today);
    if (!buckets.containsKey(label)) {
      buckets[label] = [];
      order.add(label);
    }
    buckets[label]!.add(s);
  }

  return order
      .map((label) => AssistantHistoryDateGroup(
            label: label,
            sessions: buckets[label]!,
          ))
      .toList();
}

String _dayLabel(DateTime day, DateTime today) {
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${day.year}/${p2(day.month)}/${p2(day.day)}';
}
