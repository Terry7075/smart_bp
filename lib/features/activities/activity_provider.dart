import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/activities/activity_models.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 社區活動照片 bucket（公開讀取，志工上傳）。
const String communityEventPhotosBucket = 'community-event-photos';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(Supabase.instance.client);
});

/// 社區活動清單：先 REST 載入，再訂閱 Realtime 更新。
final communityEventsProvider = AsyncNotifierProvider.autoDispose<
    CommunityEventsNotifier, List<CommunityEvent>>(
  CommunityEventsNotifier.new,
);

class CommunityEventsNotifier extends AsyncNotifier<List<CommunityEvent>> {
  StreamSubscription<List<CommunityEvent>>? _realtimeSub;

  @override
  Future<List<CommunityEvent>> build() async {
    ref.watch(authStateChangesProvider);
    ref.onDispose(() => _realtimeSub?.cancel());

    final repo = ref.read(activityRepositoryProvider);
    final initial = await repo.fetchAll();

    _realtimeSub?.cancel();
    _realtimeSub = repo.watchAll().listen(
      (next) => state = AsyncData(next),
      onError: (e, st) {
        debugPrint('[CommunityEvents] realtime error (ignored): $e');
      },
    );

    return initial;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// 將 Supabase 錯誤轉成看得懂的文字。
String communityEventFriendlyError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST205' ||
        (error.message.contains('community_events') &&
            error.message.contains('schema cache'))) {
      return '找不到 community_events 資料表。\n請到 Supabase SQL Editor 執行 migrations 內的 20260523100000_community_events.sql';
    }
    return error.message;
  }
  return error.toString();
}

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Stream<List<CommunityEvent>> watchAll() {
    return _client
        .from('community_events')
        .stream(primaryKey: const ['id'])
        .map(_parseRows);
  }

  Future<List<CommunityEvent>> fetchAll() async {
    final rows = await _client
        .from('community_events')
        .select()
        .order('event_date', ascending: true);
    return _parseRows(rows);
  }

  List<CommunityEvent> _parseRows(List<dynamic> rows) {
    final list = <CommunityEvent>[];
    for (final raw in rows) {
      try {
        list.add(CommunityEvent.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('[CommunityEvents] skip unparseable row: $e');
      }
    }
    list.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return list;
  }

  /// 新增活動。若有 [localPhotoPath] 會先上傳照片到公開 bucket，再帶入 photo_url。
  Future<void> insert({
    required String title,
    String? description,
    required DateTime eventDate,
    String? startTime,
    String? location,
    String? localPhotoPath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('尚未登入');

    String? photoUrl;
    if (localPhotoPath != null && localPhotoPath.trim().isNotEmpty) {
      photoUrl = await _uploadPhoto(userId: user.id, localPath: localPhotoPath);
    }

    final draft = CommunityEvent(
      id: '',
      createdAt: DateTime.now(),
      title: title.trim(),
      description: description?.trim(),
      eventDate: eventDate,
      startTime: startTime?.trim(),
      location: location?.trim(),
      photoUrl: photoUrl,
    );

    await _client
        .from('community_events')
        .insert(draft.toInsertMap(volunteerId: user.id));
  }

  Future<void> delete(String id) async {
    await _client.from('community_events').delete().eq('id', id);
  }

  /// 上傳照片到公開 bucket，回傳可直接顯示的 public URL。
  Future<String> _uploadPhoto({
    required String userId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('找不到剛剛挑的照片檔案，請再試一次。');
    }

    final ext = _safeExtension(localPath);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${1000 + Random().nextInt(8999)}.$ext';
    final objectPath = '$userId/$filename';

    try {
      await _client.storage.from(communityEventPhotosBucket).upload(
            objectPath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _mimeForExtension(ext),
            ),
          );
    } on StorageException catch (e) {
      throw StateError(_translateStorageError(e));
    }

    return _client.storage
        .from(communityEventPhotosBucket)
        .getPublicUrl(objectPath);
  }

  String _safeExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) return 'jpg';
    final ext = path.substring(lastDot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String _mimeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _translateStorageError(StorageException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('not found') || msg.contains('bucket')) {
      return '尚未建立活動照片 bucket（$communityEventPhotosBucket），請通知管理員執行 migration。';
    }
    if (msg.contains('row-level security') || msg.contains('policy')) {
      return '沒有上傳權限（請確認以志工帳號登入，且已套用 storage policy）。';
    }
    return '照片上傳失敗：${e.message}';
  }
}
