import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_history_date_groups.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_history_provider.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_provider.dart';

/// 側邊欄：過往小幫手對話紀錄（依日期分組、可刪除）。
class AssistantHistorySidebar extends ConsumerWidget {
  const AssistantHistorySidebar({
    super.key,
    this.onCloseDrawer,
  });

  final VoidCallback? onCloseDrawer;

  static const Color _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(assistantHistoryListProvider);
    final chat = ref.watch(assistantChatProvider);
    final activeId = chat.activeSessionId;

    return Material(
      color: const Color(0xFFF1F8E9),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '過往對話',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  if (onCloseDrawer != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: onCloseDrawer,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                onPressed: chat.loading
                    ? null
                    : () async {
                        await ref
                            .read(assistantChatProvider.notifier)
                            .startNewConversation();
                        onCloseDrawer?.call();
                      },
                icon: const Icon(Icons.add_comment, size: 24),
                label: const Text(
                  '開始新對話',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: asyncHistory.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _green),
                ),
                error: (e, st) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '無法載入紀錄',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                data: (sessions) {
                  AssistantChatSession? active;
                  if (activeId != null && !chat.viewingHistory) {
                    for (final s in sessions) {
                      if (s.id == activeId && s.hasUserMessages) {
                        active = s;
                        break;
                      }
                    }
                  }
                  final past = sessions
                      .where((s) => s.id != activeId)
                      .toList();
                  final groups = groupSessionsByDate(past);

                  if (active == null && past.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '尚無過往對話。\n開始聊天後會自動保存在這裡。',
                        style: TextStyle(fontSize: 17, height: 1.45),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      if (active != null) ...[
                        Builder(
                          builder: (context) {
                            final ongoing = active!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                                  child: Text(
                                    '進行中',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                                _HistoryTile(
                                  session: ongoing,
                                  selected: !chat.viewingHistory,
                                  subtitlePrefix: '可繼續聊',
                                  onTap: () {
                                    ref
                                        .read(assistantChatProvider.notifier)
                                        .continueSession(ongoing);
                                    onCloseDrawer?.call();
                                  },
                                  onDelete: () => _confirmDelete(
                                    context,
                                    ref,
                                    ongoing,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (groups.isNotEmpty) const Divider(height: 24),
                      ],
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: Text(
                            group.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                        ),
                        for (final s in group.sessions)
                          _HistoryTile(
                            session: s,
                            selected: chat.viewingHistory &&
                                chat.selectedHistoryId == s.id,
                            onTap: () {
                              ref
                                  .read(assistantChatProvider.notifier)
                                  .openHistorySession(s);
                              onCloseDrawer?.call();
                            },
                            onDelete: () => _confirmDelete(context, ref, s),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AssistantChatSession session,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '刪除這則對話？',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '「${session.title}」刪除後無法復原。',
          style: const TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(assistantChatProvider.notifier)
        .deleteHistorySession(session.id);
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    this.subtitlePrefix,
  });

  final AssistantChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? subtitlePrefix;

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(session.updatedAt);
    final subtitle = subtitlePrefix != null ? '$subtitlePrefix · $time' : time;

    return Card(
      elevation: selected ? 2 : 0,
      color: selected ? Colors.white : const Color(0xFFE8F5E9),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          session.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 15),
        ),
        leading: Icon(
          subtitlePrefix != null ? Icons.chat : Icons.history,
          color: const Color(0xFF2E7D32),
          size: 28,
        ),
        trailing: IconButton(
          tooltip: '刪除',
          icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 28),
          onPressed: onDelete,
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${p2(l.hour)}:${p2(l.minute)}';
  }
}
