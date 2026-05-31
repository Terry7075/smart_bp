import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Supabase Storage 內存放藥單原始照片的 bucket 名稱。
///
/// **必須在 Supabase 後台手動建立成「Private」（非公開）bucket，**
/// 並依照 README 內 SQL 設定 RLS：
/// - 長輩只能 INSERT / SELECT 自己 `{auth.uid()}/...` 路徑下的物件。
/// - 志工（profiles.role = 'volunteer'）可 SELECT 整個 bucket。
const String volunteerTaskPhotosBucket = 'volunteer-task-photos';

/// 取得 Supabase client 的小 helper provider，方便測試覆寫。
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ---------------------------------------------------------------------------
// 長輩端：送出新任務
// ---------------------------------------------------------------------------

/// 把一張 OCR 完的處方籤送進「待志工協助」清單。
///
/// 由 [`HealthScanPage._sendToVolunteer`] 在使用者按下「傳給志工幫忙」時呼叫。
/// 這個 provider 暴露成 functional API（Notifier 沒有額外狀態），方便 UI 端
/// 用 `ref.read(...).submit(...)` 寫一行就好。
final volunteerTaskSubmitterProvider = Provider<VolunteerTaskSubmitter>((ref) {
  return VolunteerTaskSubmitter(ref);
});

class VolunteerTaskSubmitter {
  VolunteerTaskSubmitter(this._ref);

  final Ref _ref;

  /// 送出一筆新的志工協助任務到 `volunteer_tasks` 資料表。
  ///
  /// 整個流程：
  /// 1. 若有帶 [imagePath]：先把原圖上傳到 Storage `volunteer-task-photos`。
  ///    上傳失敗會 rethrow，**不會**寫 DB（避免出現有任務、卻沒照片的孤兒列）。
  /// 2. 拿到 storage path 後 insert 一筆 `volunteer_tasks`。
  ///
  /// 為什麼是先 Storage、後 DB？
  /// - 順序反過來會出現「DB 寫了但檔案沒上傳」的孤兒任務，志工看到任務點開後
  ///   只看到一片空白，比現在這種「上傳失敗就整筆失敗 → 長輩可重試」更糟。
  /// - 反向風險（檔案上傳成功但 DB insert 失敗）會有 orphan 檔案，但志工端
  ///   永遠看不到那張孤兒照片，最多浪費一點 Storage 空間，可由排程清理。
  ///
  /// 參數：
  /// - [rawOcrText]：OCR 原文（不可為空；志工可選擇參考）。
  /// - [hospitalName]：解析到的醫院名（可選）。
  /// - [elderName] / [elderPhone]：聯絡資訊 snapshot；沒帶就 fallback 到
  ///   `auth.users.userMetadata.name`。
  /// - [imagePath]：原始藥單照片在裝置上的暫存檔案路徑（由 [OcrService]
  ///   塞進 [PrescriptionResult.imagePath]）；若為 `null` / 檔案不存在，
  ///   則僅送 OCR 文字、不附照片。
  ///
  /// 任何步驟失敗都會 rethrow，由 UI 端顯示錯誤訊息。
  ///
  /// 成功後會建立 `prescriptions` 列（`status = pending_verification`），與
  /// `volunteer_tasks.id` 共用同一 UUID。
  Future<void> submit({
    required String rawOcrText,
    String? hospitalName,
    String? elderName,
    String? elderPhone,
    String? imagePath,
    List<String> takeMedicineTimes = const [],
    String? medicationName,
    String? pillAppearance,
  }) async {
    if (rawOcrText.trim().isEmpty) {
      throw ArgumentError('沒有 OCR 文字內容，無法送出任務');
    }

    final client = _ref.read(_supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('尚未登入，無法送出志工任務');
    }

    String? photoPath;
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      photoPath = await _uploadPhoto(
        client: client,
        userId: user.id,
        localPath: imagePath.trim(),
      );
    }

    final taskId = const Uuid().v4();
    final preview = rawOcrText.trim().length > 800
        ? '${rawOcrText.trim().substring(0, 800)}…'
        : rawOcrText.trim();

    final payload = VolunteerTask.insertPayload(
      id: taskId,
      elderId: user.id,
      elderName: (elderName?.trim().isNotEmpty ?? false)
          ? elderName!.trim()
          : (user.userMetadata?['name'] as String?) ?? '社區長輩',
      elderPhone: elderPhone?.trim(),
      rawOcrText: rawOcrText.trim(),
      hospitalName: hospitalName?.trim(),
      photoPath: photoPath,
    );

    await client.from('volunteer_tasks').insert(payload);

    try {
      await _ref
          .read(prescriptionRepositoryProvider)
          .insertPendingVerificationPrescription(
            id: taskId,
            userId: user.id,
            hospitalName: hospitalName?.trim(),
            pickupDate: DateTime.now(),
            takeMedicineTimes: takeMedicineTimes,
            medicationName: medicationName?.trim(),
            pillAppearance: pillAppearance?.trim(),
            rawNotes: preview,
          );
    } catch (e) {
      // 藥單寫入失敗 → 回滾剛 insert 的 task，避免志工看到任務、長輩卻沒藥單。
      try {
        await client.from('volunteer_tasks').delete().eq('id', taskId);
      } catch (_) {
        // best-effort rollback
      }
      rethrow;
    }
  }

  /// 把長輩端的本機照片上傳到 Supabase Storage，回傳 object path。
  ///
  /// 路徑規則：`{user.id}/{timestamp}_{rand}.{ext}`
  /// - 第一段 segment 是 `auth.uid()`，配合 Storage RLS 的
  ///   `storage.foldername(name)[1] = auth.uid()::text` 作為 owner 判定。
  /// - timestamp + 4 碼亂數降低同 elder 同秒上傳的碰撞機率。
  ///
  /// 副檔名：保留原始檔名最後一段（限白名單）；非影像副檔名一律 fallback `jpg`。
  Future<String> _uploadPhoto({
    required SupabaseClient client,
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
      await client.storage.from(volunteerTaskPhotosBucket).upload(
            objectPath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _mimeForExtension(ext),
            ),
          );
    } on StorageException catch (e) {
      // 把常見的 RLS / bucket 不存在錯誤翻成中文，UI 才看得懂該去設定什麼。
      throw StateError(_translateStorageError(e));
    }

    return objectPath;
  }

  /// 從本機路徑抽副檔名，限制在常見影像格式內，否則 fallback `jpg`。
  String _safeExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) return 'jpg';
    final ext = path.substring(lastDot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  String _mimeForExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  String _translateStorageError(StorageException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('bucket') && msg.contains('not found')) {
      return '尚未建立照片 bucket（$volunteerTaskPhotosBucket），請通知管理員設定 Supabase Storage。';
    }
    if (msg.contains('row-level security') || msg.contains('not authorized')) {
      return '上傳照片被 Storage RLS 擋下，請通知管理員確認權限設定。';
    }
    return '上傳照片失敗：${e.message}';
  }
}

// ---------------------------------------------------------------------------
// 志工端：清單 + 認領 + 完成
// ---------------------------------------------------------------------------

/// 志工儀表板會看到的任務清單：包含「待處理」+「我自己處理中」，依時間排序。
///
/// 設計上不秀「別的志工正在處理中」的單，避免介入或誤點完成；自己沒做完的會
/// 一直顯示在清單上，提醒志工別漏掉。
final volunteerTasksProvider =
    AsyncNotifierProvider<VolunteerTasksNotifier, List<VolunteerTask>>(
  VolunteerTasksNotifier.new,
);

class VolunteerTasksNotifier extends AsyncNotifier<List<VolunteerTask>> {
  @override
  Future<List<VolunteerTask>> build() async {
    // 登入狀態變更時自動重抓，避免登出後仍快取上一個志工的清單。
    ref.listen(authStateChangesProvider, (_, _) {
      ref.invalidateSelf();
    });
    return _fetch();
  }

  /// 拉一次最新清單，UI 端可拿來做 pull-to-refresh。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// 「我接下這件任務」：把 status 從 pending 改成 in_progress，
  /// 同時把 `claimed_by / claimed_at` 寫上自己的資料。
  ///
  /// 用 `.eq('status', 'pending')` 做樂觀鎖：如果別的志工先一步認領了，
  /// 這個 update 會 0 row affected，UI 端可以 refresh 看到最新狀態。
  Future<void> claim(String taskId) async {
    final client = ref.read(_supabaseClientProvider);
    final me = client.auth.currentUser;
    if (me == null) {
      throw StateError('尚未登入，無法認領任務');
    }

    final updated = await client
        .from('volunteer_tasks')
        .update({
          'status': VolunteerTaskStatus.inProgress.dbValue,
          'claimed_by': me.id,
          'claimed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', taskId)
        .eq('status', VolunteerTaskStatus.pending.dbValue)
        .select();

    if (updated.isEmpty) {
      // 別的志工先一步認領，重抓清單讓 UI 顯示最新狀態。
      await refresh();
      throw StateError('這件任務已經被其他志工接走囉，幫您更新清單。');
    }

    await refresh();
  }

  /// 「✅ 已完成」：把 in_progress 改成 done。可附 [notes] 備註此次協助結果。
  Future<void> markDone(String taskId, {String? notes}) async {
    final client = ref.read(_supabaseClientProvider);
    final me = client.auth.currentUser;
    if (me == null) {
      throw StateError('尚未登入');
    }

    await client
        .from('volunteer_tasks')
        .update({
          'status': VolunteerTaskStatus.done.dbValue,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .eq('id', taskId)
        .eq('claimed_by', me.id);

    await refresh();
  }

  /// 「✅ 填表確認並回傳」：志工人工補登 + 把任務狀態推到 `active`。
  ///
  /// 同時把這四個欄位寫回 Supabase：
  /// - [hospitalName]：志工修正過的醫院名稱
  /// - [pickupDate]：志工選的下次領藥日（純日期，不含時間）
  /// - [takeMedicineTimes]：志工勾選的服藥時段（HH:mm 字串清單，已排序）
  /// - `status` → `active`
  ///
  /// 寫入後長輩端的 Realtime stream（[`latestPrescriptionStreamProvider`]）會在
  /// 1~2 秒內收到 row update，首頁卡片自動切到「✅ 已確認」並排好鬧鐘。
  ///
  /// 用 `.eq('claimed_by', me.id)` 確保只有「自己接過的單」可以由自己回傳，
  /// 避免志工 A 改到志工 B 處理中的單。
  Future<void> verify({
    required String taskId,
    required String hospitalName,
    required DateTime pickupDate,
    required List<String> takeMedicineTimes,
  }) async {
    if (hospitalName.trim().isEmpty) {
      throw ArgumentError('請輸入醫院名稱');
    }
    if (takeMedicineTimes.isEmpty) {
      throw ArgumentError('請至少勾選一個服藥時段');
    }

    final client = ref.read(_supabaseClientProvider);
    final me = client.auth.currentUser;
    if (me == null) {
      throw StateError('尚未登入');
    }

    // pickup_date 用 yyyy-MM-dd 字串送，避免時區把日期推到前一天。
    final pickupIsoDate = '${pickupDate.year.toString().padLeft(4, '0')}-'
        '${pickupDate.month.toString().padLeft(2, '0')}-'
        '${pickupDate.day.toString().padLeft(2, '0')}';

    final updated = await client
        .from('volunteer_tasks')
        .update({
          'status': VolunteerTaskStatus.active.dbValue,
          'hospital_name': hospitalName.trim(),
          'pickup_date': pickupIsoDate,
          'take_medicine_times': takeMedicineTimes,
        })
        .eq('id', taskId)
        .eq('claimed_by', me.id)
        .eq('status', VolunteerTaskStatus.inProgress.dbValue)
        .select();

    if (updated.isEmpty) {
      throw StateError('這件任務可能已被別人處理，請下拉重新整理。');
    }

    final row = Map<String, dynamic>.from(updated.first as Map);
    final elderId = row['elder_id'] as String;

    // 同步 prescriptions → active（長輩端 Realtime 才會更新健康頁／通知）。
    // 失敗時把 task 退回 in_progress，避免「志工以為完成、長輩仍待審核」split-brain。
    try {
      await ref.read(prescriptionRepositoryProvider).activateFromVolunteerTask(
            id: taskId,
            userId: elderId,
            hospitalName: hospitalName.trim(),
            pickupDate: pickupDate,
            takeMedicineTimes: takeMedicineTimes,
          );
    } catch (e) {
      try {
        await client
            .from('volunteer_tasks')
            .update({'status': VolunteerTaskStatus.inProgress.dbValue})
            .eq('id', taskId)
            .eq('claimed_by', me.id);
      } catch (_) {
        // best-effort revert
      }
      throw StateError('藥單同步失敗，請再試一次。（$e）');
    }

    await refresh();
  }

  /// 內部：抓「待處理 + 我自己處理中」兩種狀態，依建立時間倒序。
  Future<List<VolunteerTask>> _fetch() async {
    final client = ref.read(_supabaseClientProvider);
    final me = client.auth.currentUser;
    if (me == null) return const <VolunteerTask>[];

    // Supabase Dart SDK：先 select、後 filter、最後 order，是固定順序。
    final rows = await client
        .from('volunteer_tasks')
        .select()
        .or(
          'status.eq.${VolunteerTaskStatus.pending.dbValue},'
          'and(status.eq.${VolunteerTaskStatus.inProgress.dbValue},claimed_by.eq.${me.id})',
        )
        .order('created_at', ascending: false);

    return [
      for (final row in rows as List<dynamic>)
        VolunteerTask.fromMap(row as Map<String, dynamic>),
    ];
  }
}

// ---------------------------------------------------------------------------
// 長輩端：Realtime 訂閱「我自己最新一筆藥單任務」
// ---------------------------------------------------------------------------

/// 長輩端首頁用的 Realtime 串流：監聽當前登入長輩在 `volunteer_tasks` 裡
/// 「最新一筆」的狀態變化。
///
/// 設計細節：
/// - 用 Supabase Dart SDK 的 `.stream(...)` API（透過 Realtime / Postgres
///   replication），志工那邊 `update` 完幾乎即時推到長輩裝置。
/// - 用 `.eq('elder_id', me.id)` 服務端過濾，配合 `volunteer_tasks` 的 RLS
///   `elder_id = auth.uid()`，雙重保險避免讀到別人的單。
/// - SDK 的 `.stream(...)` 不直接支援 `order/limit`，所以我們在 Dart 端
///   `map` 取最新一筆（list 內已包含該長輩所有 row）。
/// - 沒登入或還沒送過任何藥單時，stream 會發出 `null`，UI 顯示空狀態即可。
final latestPrescriptionStreamProvider =
    StreamProvider<VolunteerTask?>((ref) {
  // 登入狀態變化（登出 / 切帳號）時自動重建 stream。
  ref.watch(authStateChangesProvider);

  final client = ref.read(_supabaseClientProvider);
  final me = client.auth.currentUser;
  if (me == null) {
    return Stream<VolunteerTask?>.value(null);
  }

  return client
      .from('volunteer_tasks')
      .stream(primaryKey: ['id'])
      .eq('elder_id', me.id)
      .map<VolunteerTask?>((rows) {
        if (rows.isEmpty) return null;

        // 端對端拿最新一筆：依 created_at 字串排序（ISO 8601 字典序 = 時序）。
        final sorted = [...rows]..sort((a, b) {
          final av = (a['created_at'] as String?) ?? '';
          final bv = (b['created_at'] as String?) ?? '';
          return bv.compareTo(av);
        });
        return VolunteerTask.fromMap(sorted.first);
      });
});
