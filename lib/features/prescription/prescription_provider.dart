import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../volunteer/batch_refill_models.dart';
import 'prescription_models.dart';

/// 長輩藥單原始照片的私人 bucket（志工代領時核對原圖）。
///
/// 只有長輩勾選「需要志工代領」時才上傳；一般掃描不會把照片傳到志工端。
const String prescriptionPhotosBucket = 'prescription-photos';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(Supabase.instance.client);
});

/// 登入長輩的「使用中」藥單清單。
///
/// 隨 `authStateChangesProvider` 變更時自動重建，確保登出／換帳號會清空。
final activePrescriptionsProvider =
    FutureProvider.autoDispose<List<PrescriptionRecord>>((ref) async {
  ref.watch(authStateChangesProvider);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const [];

  final repo = ref.read(prescriptionRepositoryProvider);
  return repo.fetchActiveForUser(user.id);
});

/// 登入長輩名下所有藥單的 Realtime stream（含待審核、使用中、代領狀態等）。
final elderPrescriptionsStreamProvider =
    StreamProvider.autoDispose<List<PrescriptionRecord>>((ref) {
  ref.watch(authStateChangesProvider);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const Stream.empty();

  return ref
      .read(prescriptionRepositoryProvider)
      .watchPrescriptionsForUser(user.id);
});

class PrescriptionRepository {
  PrescriptionRepository(this._client);

  final SupabaseClient _client;

  static String _effectiveMedicationName(String? medicationName) {
    final t = medicationName?.trim() ?? '';
    return t.isNotEmpty ? t : kMedicationNamePlaceholder;
  }

  /// 依 ID 讀取單筆藥單（打卡頁顯示藥丸外觀用）。
  Future<PrescriptionRecord?> fetchById(String prescriptionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from('prescriptions')
        .select()
        .eq('id', prescriptionId)
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;
    return PrescriptionRecord.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<PrescriptionRecord>> fetchActiveForUser(String userId) async {
    final rows = await _client
        .from('prescriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .inFilter('vision_status', const [
          VisionStatus.none,
          VisionStatus.completed,
        ])
        .order('created_at', ascending: false);

    return [
      for (final row in rows as List<dynamic>)
        PrescriptionRecord.fromMap(row as Map<String, dynamic>),
    ];
  }

  /// 清掉不應顯示在「我的藥單」的 Vision 占位列（failed / 過期 processing）。
  ///
  /// 若 DELETE 被 RLS 擋下，改 soft-cancel（`status='cancelled'`）。
  Future<void> cleanupHiddenVisionPrescriptions(
    List<PrescriptionRecord> prescriptions,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    final now = DateTime.now();
    for (final rx in prescriptions) {
      if (rx.userId != uid || !rx.isActive) continue;

      final shouldRemove = rx.visionStatus == VisionStatus.failed ||
          (rx.visionStatus == VisionStatus.processing &&
              now.difference(rx.createdAt) > const Duration(minutes: 15));
      if (!shouldRemove) continue;

      try {
        final deleted = await _client
            .from('prescriptions')
            .delete()
            .eq('id', rx.id)
            .eq('user_id', uid)
            .select('id');
        if ((deleted as List).isEmpty) {
          await _client
              .from('prescriptions')
              .update({
                'status': 'cancelled',
                'vision_status': VisionStatus.failed,
              })
              .eq('id', rx.id)
              .eq('user_id', uid);
        }
      } catch (_) {
        // best-effort；UI 仍會用 isManageablePrescription 過濾。
      }
    }
  }

  /// Realtime：該使用者名下所有藥單列（含 `pending_verification` / `active` 等）。
  Stream<List<PrescriptionRecord>> watchPrescriptionsForUser(String userId) {
    return _client
        .from('prescriptions')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final list = <PrescriptionRecord>[
            for (final raw in rows)
              PrescriptionRecord.fromMap(Map<String, dynamic>.from(raw)),
          ];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// 長輩將藥單送給志工協助時寫入，與 `volunteer_tasks.id` 相同 UUID。
  Future<void> insertPendingVerificationPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    DateTime? pickupDate,
    List<String> takeMedicineTimes = const [],
    String? pillAppearance,
    String? rawNotes,
  }) async {
    final pickup = pickupDate ?? DateTime.now();
    await _client.from('prescriptions').insert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickup),
      'take_medicine_times': takeMedicineTimes,
      if (pillAppearance != null && pillAppearance.trim().isNotEmpty)
        'pill_appearance': pillAppearance.trim(),
      if (rawNotes != null && rawNotes.isNotEmpty) 'notes': rawNotes,
      'status': 'pending_verification',
      'source': 'volunteer',
    });
  }

  /// OCR 掃描完成後寫入一筆（[id] 由呼叫端用 UUID v4 產生，方便預先排通知）。
  ///
  /// 用 **upsert**（以 PK `id` 為衝突鍵）而非 insert：
  /// - 一般本機解析：[id] 為新 UUID → 等同 insert。
  /// - 雲端配額滿改走本地備援：[id] 沿用占位列 → 直接覆寫同一列，
  ///   避免「刪占位列 + 另開新列」造成重複／幽靈藥單。
  /// - 也順帶防止使用者連點兩次「確認」而插出兩筆。
  ///
  /// [visionStatus] 有值時一併寫入（本地備援會傳 completed，把占位列從
  /// processing 轉為終態，否則會被當成處理中而被清理或卡在轉圈）。
  Future<void> insertOcrPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    required DateTime pickupDate,
    List<String> takeMedicineTimes = const [],
    int? medicationDays,
    DateTime? baselineDate,
    String? pillAppearance,
    String? rawNotes,
    String refillStatus = RefillStatus.none,
    String? photoStoragePath,
    String? visionStatus,
  }) async {
    await _client.from('prescriptions').upsert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickupDate),
      'take_medicine_times': takeMedicineTimes,
      if (medicationDays case final int d) 'medication_days': d,
      if (baselineDate case final DateTime b) 'baseline_date': _formatIsoDate(b),
      if (pillAppearance != null && pillAppearance.trim().isNotEmpty)
        'pill_appearance': pillAppearance.trim(),
      if (rawNotes != null && rawNotes.isNotEmpty) 'notes': rawNotes,
      if (photoStoragePath != null && photoStoragePath.trim().isNotEmpty)
        'photo_storage_path': photoStoragePath.trim(),
      if (visionStatus != null) 'vision_status': visionStatus,
      'refill_status': refillStatus,
      'status': 'active',
      'source': 'ocr',
    });
  }

  /// 長輩勾選「需要志工代領」後，寫入本次／下次領藥日與代領狀態。
  ///
  /// Vision 流程占位列已存在時用 UPDATE；與 [insertOcrPrescription] 的
  /// 代領欄位語意一致。
  Future<void> updateVolunteerRefillSchedule({
    required String prescriptionId,
    required DateTime nextPickupDate,
    required DateTime baselineDate,
    int? medicationDays,
    String refillStatus = RefillStatus.pendingCollection,
    String? photoStoragePath,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    final payload = <String, dynamic>{
      'pickup_date': _formatIsoDate(nextPickupDate),
      'baseline_date': _formatIsoDate(baselineDate),
      'refill_status': refillStatus,
    };
    if (medicationDays case final int d) {
      payload['medication_days'] = d;
    }
    if (photoStoragePath != null && photoStoragePath.trim().isNotEmpty) {
      payload['photo_storage_path'] = photoStoragePath.trim();
    }

    final updated = await _client
        .from('prescriptions')
        .update(payload)
        .eq('id', prescriptionId)
        .eq('user_id', uid)
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError('更新代領日程失敗：資料庫沒有更新這張藥單。');
    }
  }

  /// 長輩端補同步：優先 UPDATE 既有列（避免 upsert 觸發 INSERT RLS 問題）。
  Future<void> activateFromVolunteerTask({
    required String id,
    required String userId,
    String? hospitalName,
    required DateTime pickupDate,
    List<String> takeMedicineTimes = const [],
    String? medicationName,
    String? pillAppearance,
  }) async {
    final payload = <String, dynamic>{
      'pickup_date': _formatIsoDate(pickupDate),
      'take_medicine_times': takeMedicineTimes,
      'status': 'active',
      'source': 'volunteer',
    };
    if (hospitalName != null && hospitalName.trim().isNotEmpty) {
      payload['hospital_name'] = hospitalName.trim();
    }

    final updated = await _client
        .from('prescriptions')
        .update(payload)
        .eq('id', id)
        .eq('user_id', userId)
        .select();

    if ((updated as List).isEmpty) {
      await upsertVolunteerPrescription(
        id: id,
        userId: userId,
        hospitalName: hospitalName,
        medicationName: medicationName,
        pickupDate: pickupDate,
        takeMedicineTimes: takeMedicineTimes,
        pillAppearance: pillAppearance,
      );
    }
  }

  /// 志工協助確認後同步建立／更新（UUID 與 `volunteer_tasks.id` 對齊）。
  Future<void> upsertVolunteerPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    required DateTime pickupDate,
    List<String> takeMedicineTimes = const [],
    int? medicationDays,
    String? pillAppearance,
  }) async {
    await _client.from('prescriptions').upsert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickupDate),
      'take_medicine_times': takeMedicineTimes,
      if (medicationDays case final int d) 'medication_days': d,
      if (pillAppearance != null && pillAppearance.trim().isNotEmpty)
        'pill_appearance': pillAppearance.trim(),
      'status': 'active',
      'source': 'volunteer',
    });
  }

  /// 回寫服藥時段到既有藥單列（Vision 流程：占位列已存在，使用者在
  /// 確認頁可能改過時段，需同步 DB 否則「通知時間」會與「健康卡 / 打卡頁
  /// 顯示時段」對不上）。
  Future<void> updateTakeMedicineTimes({
    required String prescriptionId,
    required List<String> takeMedicineTimes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    await _client
        .from('prescriptions')
        .update({'take_medicine_times': takeMedicineTimes})
        .eq('id', prescriptionId)
        .eq('user_id', uid);
  }

  /// 上傳長輩拍的原始藥單照片到 `prescription-photos` 私人 bucket。
  ///
  /// 只在長輩勾選「需要志工代領」時呼叫——志工才看得到、也才需要核對原圖。
  /// 路徑規則 `{auth.uid()}/{timestamp}_{rand}.{ext}` 對齊 Storage RLS：
  /// 長輩只能讀寫自己資料夾，志工（role='volunteer'）可讀整個 bucket。
  ///
  /// 回傳 object path（寫進 `prescriptions.photo_storage_path`）。
  Future<String> uploadPrescriptionPhoto({
    required String localPath,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('找不到剛剛拍的照片檔案，請再試一次。');
    }

    final ext = _safePhotoExtension(localPath);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${1000 + Random().nextInt(8999)}.$ext';
    final objectPath = '$uid/$filename';

    await _client.storage.from(prescriptionPhotosBucket).upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _mimeForPhotoExtension(ext),
          ),
        );

    return objectPath;
  }

  static String _safePhotoExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) return 'jpg';
    final ext = path.substring(lastDot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  static String _mimeForPhotoExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// 長輩在確認頁修正用藥天數後回寫（Vision 占位列或一般 OCR 皆適用）。
  Future<void> updateMedicationDays({
    required String prescriptionId,
    required int medicationDays,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    final updated = await _client
        .from('prescriptions')
        .update({'medication_days': medicationDays})
        .eq('id', prescriptionId)
        .eq('user_id', uid)
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError('更新用藥天數失敗：資料庫沒有更新這張藥單。');
    }
  }

  /// 軟刪除：把藥單狀態設為 `cancelled`（不再對外顯示但 DB 仍保留）。
  ///
  /// 目前 UI 已改成走 [deletePrescription]（硬刪除），這個方法保留只給
  /// 未來特殊用途——例如政府稽核要求「曾經有過但停止使用」的紀錄。
  Future<void> setCancelled(String prescriptionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    await _client
        .from('prescriptions')
        .update({'status': 'cancelled'})
        .eq('id', prescriptionId)
        .eq('user_id', uid);
  }

  /// 硬刪除：實際 DELETE 該列藥單。
  ///
  /// 若已申請志工代領（`refill_status` 非 none），改為軟保留：
  /// `status=cancelled`、`refill_status=prescription_deleted`，志工端仍看得到
  /// 並提示「此藥單已被刪除，請再次確認」。
  ///
  /// 注意：Supabase 在 RLS 拒絕 DELETE 時**不會 throw**，只會回傳空陣列。
  /// 因此必須 `.select('id')` 確認真的有刪到，否則 UI 會誤顯示「已刪除」。
  Future<void> deletePrescription(String prescriptionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    final row = await _client
        .from('prescriptions')
        .select('refill_status')
        .eq('id', prescriptionId)
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) {
      throw StateError('找不到這張藥單，可能已被刪除。');
    }

    final refillStatus =
        (row['refill_status'] as String?) ?? RefillStatus.none;

    if (RefillStatus.shouldRetainVolunteerRefillOnDelete(refillStatus)) {
      final updated = await _client
          .from('prescriptions')
          .update({
            'status': 'cancelled',
            'refill_status': RefillStatus.prescriptionDeleted,
          })
          .eq('id', prescriptionId)
          .eq('user_id', uid)
          .select('id');

      if ((updated as List).isEmpty) {
        throw StateError('刪除失敗：無法更新這張藥單（可能是權限問題）。');
      }
      return;
    }

    // 志工任務與 prescriptions 常共用 UUID；只 cancel 自己的任務。
    try {
      await _client
          .from('volunteer_tasks')
          .update({'status': 'cancelled'})
          .eq('id', prescriptionId)
          .eq('elder_id', uid);
    } catch (_) {
      // 沒有對應任務或 RLS 不允許更新時略過，不阻斷刪除藥單。
    }

    final deleted = await _client
        .from('prescriptions')
        .delete()
        .eq('id', prescriptionId)
        .eq('user_id', uid)
        .select('id');

    if ((deleted as List).isEmpty) {
      throw StateError(
        '刪除失敗：資料庫沒有刪到這張藥單。\n'
        '請到 Supabase SQL Editor 執行：\n'
        'supabase/migrations/20260508211000_prescriptions_delete_fix.sql',
      );
    }
  }

  /// 志工確認「長輩已刪除藥單」後結案，移出代領清單。
  Future<void> dismissDeletedPrescriptionRefill(String prescriptionId) async {
    final updated = await _client.from('prescriptions').update({
      'refill_status': RefillStatus.none,
      'has_health_card': false,
    }).eq('id', prescriptionId).select('id');

    if ((updated as List).isEmpty) {
      throw StateError('結案失敗：資料庫沒有更新這張代領項目。');
    }
  }

  // ---------------------------------------------------------------------------
  // 志工批次代領
  // ---------------------------------------------------------------------------

  /// 志工端：監聽所有可見的 active 藥單並分群（10 天寬限期）。
  Stream<List<BatchRefillGroup>> watchBatchRefillGroups() {
    return _client
        .from('prescriptions')
        .stream(primaryKey: const ['id'])
        .asyncMap((rows) async {
          final prescriptions = <PrescriptionRecord>[
            for (final raw in rows)
              PrescriptionRecord.fromMap(Map<String, dynamic>.from(raw)),
          ];

          final userIds = prescriptions.map((r) => r.userId).toSet().toList();
          final names = await fetchProfileNamesByUserIds(userIds);

          return groupPrescriptionsForBatchRefill(
            prescriptions: prescriptions,
            elderNamesByUserId: names,
          );
        });
  }

  Future<Map<String, String>> fetchProfileNamesByUserIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};

    final rows = await _client
        .from('profiles')
        .select('id, name')
        .inFilter('id', userIds);

    final map = <String, String>{};
    for (final raw in rows as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['id'] as String?;
      final name = row['name'] as String?;
      if (id != null && name != null && name.trim().isNotEmpty) {
        map[id] = name.trim();
      }
    }
    return map;
  }

  Future<void> setRefillHealthCard({
    required String prescriptionId,
    required bool hasHealthCard,
    required String refillStatus,
  }) async {
    final updated = await _client.from('prescriptions').update({
      'has_health_card': hasHealthCard,
      'refill_status': refillStatus,
    }).eq('id', prescriptionId).select('id');

    if ((updated as List).isEmpty) {
      throw StateError('更新失敗：資料庫沒有更新這張藥單（可能是權限問題）。');
    }
  }

  /// 領藥完成：展延領藥日、重置代領狀態（略過長輩已刪除的藥單）。
  Future<void> completeBatchRefill(
    List<PrescriptionRecord> prescriptions,
  ) async {
    for (final rx in prescriptions) {
      if (RefillStatus.isPrescriptionDeletedByElder(rx.refillStatus)) {
        continue;
      }
      final extendDays = rx.medicationDays ?? 28;
      final base = rx.pickupDate ?? DateTime.now();
      final baseOnly = DateTime(base.year, base.month, base.day);
      final nextPickup = baseOnly.add(Duration(days: extendDays));

      final updated = await _client.from('prescriptions').update({
        'pickup_date': _formatIsoDate(nextPickup),
        'refill_status': RefillStatus.none,
        'has_health_card': false,
      }).eq('id', rx.id).select('id');

      if ((updated as List).isEmpty) {
        throw StateError('領藥完成更新失敗：${rx.medicationName}');
      }
    }
  }

  /// 藥局缺藥：整批標記調貨中。
  Future<void> reportBatchOutOfStock(
    List<String> prescriptionIds,
  ) async {
    for (final id in prescriptionIds) {
      final updated = await _client.from('prescriptions').update({
        'refill_status': RefillStatus.outOfStock,
      }).eq('id', id).select('id');

      if ((updated as List).isEmpty) {
        throw StateError('缺藥標記失敗：$id');
      }
    }
  }

  Future<void> insertMedicationLog({
    required String prescriptionId,
    String? slotTime,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    await _client.from('medication_logs').insert({
      'user_id': uid,
      'prescription_id': prescriptionId,
      if (slotTime != null && slotTime.isNotEmpty) 'slot_time': slotTime,
    });
  }

  /// 「今日是否已打卡」查詢。
  ///
  /// - 帶 [slotTime]（例：`08:00`）→ 嚴格比對該時段是否打過。
  /// - 不帶 [slotTime] → 視為「今天這張藥單是否曾經打過任何卡」。
  ///
  /// 為什麼要做這個檢查？舊版本沒有任何「同一日同一時段」鎖定，長輩看到
  /// 通知會按一次、回家又從健康頁卡片再按一次，每次都會 insert 一筆。
  /// `medication_logs` 一旦虛胖，志工報表的服藥率就完全失真。
  Future<bool> hasLoggedToday({
    required String prescriptionId,
    String? slotTime,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;

    // 用「本地時區」的今日 00:00～次日 00:00，再轉成 UTC ISO 字串給 Postgres。
    // 直接用 UTC 切會讓台灣 08:00 之前 / 之後跨日的判定錯。
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final base = _client
        .from('medication_logs')
        .select('id')
        .eq('user_id', uid)
        .eq('prescription_id', prescriptionId)
        .gte('created_at', todayStart.toUtc().toIso8601String())
        .lt('created_at', tomorrowStart.toUtc().toIso8601String());

    final filtered = (slotTime != null && slotTime.isNotEmpty)
        ? base.eq('slot_time', slotTime)
        : base;

    final rows = await filtered.limit(1);
    return (rows as List).isNotEmpty;
  }

  String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
