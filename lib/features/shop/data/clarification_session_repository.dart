import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/shop/domain/shop_nlu_result.dart';

/// 多輪澄清會話（Supabase `clarification_sessions`）。
class ClarificationSessionRepository {
  ClarificationSessionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> upsert({
    String? sessionId,
    ShopNluResult? partialNlu,
    List<String>? missingFields,
    String? utterance,
    String? resolveItemId,
  }) async {
    final id = await _client.rpc(
      'upsert_clarification_session',
      params: {
        'p_session_id': sessionId,
        'p_partial_nlu': partialNlu?.toJson() ?? {},
        'p_missing_fields': missingFields ?? partialNlu?.missingFields ?? [],
        'p_utterance': utterance,
        'p_resolve_item_id': resolveItemId,
      },
    );
    return id?.toString() ?? '';
  }

  Future<Map<String, dynamic>?> fetchOpenSession(String userId) async {
    try {
      final row = await _client
          .from('clarification_sessions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'open')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  ShopNluResult? partialFromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final partial = row['partial_nlu'];
    if (partial is! Map) return null;
    return ShopNluResult.fromJson(Map<String, dynamic>.from(partial));
  }

  List<String> missingFromRow(Map<String, dynamic>? row) {
    if (row == null) return const [];
    final m = row['missing_fields'];
    if (m is! List) return const [];
    return m.map((e) => e.toString()).toList();
  }
}
