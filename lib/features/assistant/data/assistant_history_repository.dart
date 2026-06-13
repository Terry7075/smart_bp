import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_bp/features/assistant/domain/assistant_chat_session.dart';
import 'package:smart_bp/features/assistant/domain/assistant_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 小幫手對話歷史：優先 Supabase 雲端，失敗時 fallback 本機。
class AssistantHistoryRepository {
  static const _maxSessions = 40;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AssistantChatSession>> loadSessions(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final rows = await _client
          .from('assistant_chat_sessions')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(_maxSessions);
      final list = List<dynamic>.from(rows as List? ?? const []);
      return list
          .map((e) => _sessionFromSupabaseRow(Map<String, dynamic>.from(e as Map)))
          .where((s) => s.hasUserMessages)
          .toList();
    } catch (e) {
      debugPrint('[AssistantHistory] Supabase load failed: $e');
      return _loadSessionsLocal(userId);
    }
  }

  Future<void> deleteSession({
    required String userId,
    required String sessionId,
  }) async {
    if (userId.isEmpty || sessionId.isEmpty) return;

    try {
      await _client
          .from('assistant_chat_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[AssistantHistory] Supabase delete failed: $e');
    }

    final all = await _loadSessionsLocal(userId);
    final next = all.where((s) => s.id != sessionId).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(userId),
      jsonEncode(next.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> upsertSession(AssistantChatSession session) async {
    if (session.userId.isEmpty || !session.hasUserMessages) return;

    try {
      await _client.from('assistant_chat_sessions').upsert({
        'id': session.id,
        'user_id': session.userId,
        'title': session.title,
        'messages': session.messages.map((m) => m.toJson()).toList(),
        'started_at': session.startedAt.toIso8601String(),
        'updated_at': session.updatedAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[AssistantHistory] Supabase upsert failed: $e');
    }

    await _upsertSessionLocal(session);
  }

  AssistantChatSession _sessionFromSupabaseRow(Map<String, dynamic> row) {
    final rawMsgs = row['messages'];
    final msgs = <AssistantMessage>[];
    if (rawMsgs is List) {
      for (final e in rawMsgs) {
        if (e is Map) {
          msgs.add(AssistantMessage.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    } else if (rawMsgs is String) {
      try {
        final decoded = jsonDecode(rawMsgs);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              msgs.add(
                AssistantMessage.fromJson(Map<String, dynamic>.from(e)),
              );
            }
          }
        }
      } catch (_) {}
    }

    return AssistantChatSession(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      startedAt: DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: row['title']?.toString() ?? '對話紀錄',
      messages: msgs,
    );
  }

  Future<List<AssistantChatSession>> _loadSessionsLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final sessions = <AssistantChatSession>[];
      for (final e in list) {
        if (e is Map) {
          sessions.add(
            AssistantChatSession.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  Future<void> _upsertSessionLocal(AssistantChatSession session) async {
    final all = await _loadSessionsLocal(session.userId);
    final next = [
      session,
      ...all.where((s) => s.id != session.id),
    ];
    final trimmed = next.take(_maxSessions).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(session.userId),
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
  }

  String _storageKey(String userId) => 'assistant_history_v1_$userId';
}

final assistantHistoryRepositoryProvider =
    Provider<AssistantHistoryRepository>((ref) => AssistantHistoryRepository());
