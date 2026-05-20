import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_history_repository.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';

/// 目前登入者的小幫手歷史對話列表（側邊欄用）。
final assistantHistoryListProvider =
    FutureProvider<List<AssistantChatSession>>((ref) async {
  final session = ref.watch(authProvider);
  final userId = session?.user.id;
  if (userId == null || userId.isEmpty) return [];
  return ref.read(assistantHistoryRepositoryProvider).loadSessions(userId);
});
