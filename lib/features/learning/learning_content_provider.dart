import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/learning/learning_content_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final learningContentRepositoryProvider =
    Provider<LearningContentRepository>((ref) {
  return LearningContentRepository(Supabase.instance.client);
});

/// 學習內容清單：先 REST 載入（可靠），再訂閱 Realtime 更新。
final learningContentProvider = AsyncNotifierProvider.autoDispose<
    LearningContentNotifier, List<LearningContent>>(
  LearningContentNotifier.new,
);

class LearningContentNotifier extends AsyncNotifier<List<LearningContent>> {
  StreamSubscription<List<LearningContent>>? _realtimeSub;

  @override
  Future<List<LearningContent>> build() async {
    ref.watch(authStateChangesProvider);
    ref.onDispose(() => _realtimeSub?.cancel());

    final repo = ref.read(learningContentRepositoryProvider);
    final initial = await repo.fetchAll();

    _realtimeSub?.cancel();
    _realtimeSub = repo.watchAll().listen(
      (next) {
        state = AsyncData(next);
      },
      onError: (e, st) {
        // Realtime 未開啟時不影響已載入的 REST 資料
        debugPrint('[LearningContent] realtime error (ignored): $e');
      },
    );

    return initial;
  }

  /// 重新整理：用 invalidateSelf 觸發 [build] 完整重跑，
  /// 這樣 REST 與 Realtime 訂閱都會重新建立（只重打 REST 的話，
  /// 初次 Realtime 失敗後即使重試也吃不到後續更新）。
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 將 Supabase 錯誤轉成長輩／志工看得懂的文字。
String learningContentFriendlyError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST205' ||
        error.message.contains('learning_content') &&
            error.message.contains('schema cache')) {
      return '找不到 learning_content 資料表。\n請到 Supabase SQL Editor 執行 migrations 資料夾內的 20260508170000_learning_content.sql';
    }
    return error.message;
  }
  return error.toString();
}

class LearningContentRepository {
  LearningContentRepository(this._client);

  final SupabaseClient _client;

  /// Realtime 更新用（需將表加入 supabase_realtime publication）。
  Stream<List<LearningContent>> watchAll() {
    return _client.from('learning_content').stream(primaryKey: const ['id']).map(
      (rows) => _parseRows(rows),
    );
  }

  Future<List<LearningContent>> fetchAll() async {
    final rows = await _client
        .from('learning_content')
        .select()
        .order('created_at', ascending: false);
    return _parseRows(rows);
  }

  List<LearningContent> _parseRows(List<dynamic> rows) {
    final list = <LearningContent>[];
    for (final raw in rows) {
      try {
        list.add(LearningContent.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        // 單筆髒資料不該讓整個清單炸掉；跳過該筆並記 log 即可。
        debugPrint('[LearningContent] skip unparseable row: $e');
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> insert(LearningContent draft, {required String volunteerId}) async {
    await _client.from('learning_content').insert({
      ...draft.toInsertMap(volunteerId: volunteerId),
    });
  }

  Future<void> update({
    required String id,
    required String title,
    String? description,
    required String category,
    required String contentType,
    required String url,
  }) async {
    await _client.from('learning_content').update({
      'title': title,
      'description':
          (description == null || description.isEmpty) ? null : description,
      'category': category,
      'content_type': contentType,
      'url': url,
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('learning_content').delete().eq('id', id);
  }
}

List<LearningContent> filterByCategories(
  List<LearningContent> all,
  List<String> categories,
) {
  final set = categories.toSet();
  return all.where((c) => set.contains(c.category)).toList(growable: false);
}

List<LearningContent> filterByCategory(
  List<LearningContent> all,
  String category,
) =>
    all.where((c) => c.category == category).toList(growable: false);
