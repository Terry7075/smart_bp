import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_history_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';

/// 對話歷史頁（第五章）：時間軸＋意圖類別標籤。
class AssistantChatHistoryPage extends ConsumerStatefulWidget {
  const AssistantChatHistoryPage({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<AssistantChatHistoryPage> createState() =>
      _AssistantChatHistoryPageState();
}

class _AssistantChatHistoryPageState extends ConsumerState<AssistantChatHistoryPage> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.sessionId;
  }

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assistantHistoryListProvider);

    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text(
            '對話歷史',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => context.pop(),
          ),
        ),
        body: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _green)),
          error: (e, _) => Center(child: Text('載入失敗：$e')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const Center(
                child: Text('尚無對話紀錄', style: TextStyle(fontSize: 20)),
              );
            }
            final sid = _selectedId ?? sessions.first.id;
            final selected = sessions.firstWhere(
              (s) => s.id == sid,
              orElse: () => sessions.first,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: ListView(
                    children: [
                      for (final s in sessions)
                        ListTile(
                          selected: s.id == _selectedId,
                          title: Text(
                            s.title,
                            style: const TextStyle(fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatTime(s.updatedAt),
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => setState(() => _selectedId = s.id),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _TimelineView(session: selected),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.session});

  final AssistantChatSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          session.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final m in session.messages) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    m.isUser ? Icons.person : Icons.smart_toy,
                    color: m.isUser ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    size: 28,
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _AssistantChatHistoryPageState._formatTime(m.at),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    if (m.intentLabel != null) ...[
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          m.intentLabel!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        backgroundColor: const Color(0xFFE8F5E9),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      m.text,
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
