import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/core/notification_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 長輩端：志工已確認、待顯示 SnackBar 的任務（由首頁監聽後清空）。
final elderVolunteerConfirmSnackProvider =
    NotifierProvider<_ElderVolunteerConfirmSnack, VolunteerTask?>(
  _ElderVolunteerConfirmSnack.new,
);

class _ElderVolunteerConfirmSnack extends Notifier<VolunteerTask?> {
  @override
  VolunteerTask? build() => null;

  void notifyTask(VolunteerTask task) => state = task;

  void clear() => state = null;
}

/// 長輩名下所有 `volunteer_tasks`（Realtime，非只取最新一筆）。
final elderVolunteerTasksStreamProvider =
    StreamProvider.autoDispose<List<VolunteerTask>>((ref) {
  ref.watch(authStateChangesProvider);
  final me = Supabase.instance.client.auth.currentUser;
  if (me == null) return const Stream.empty();

  return Supabase.instance.client
      .from('volunteer_tasks')
      .stream(primaryKey: const ['id'])
      .eq('elder_id', me.id)
      .map((rows) {
        final list = <VolunteerTask>[
          for (final raw in rows)
            VolunteerTask.fromMap(Map<String, dynamic>.from(raw)),
        ];
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

/// 通知鈴鐺紅點數：待審核 + 缺藥 + 志工已確認但藥單尚未同步為 active。
final elderNotificationBadgeCountProvider = Provider.autoDispose<int>((ref) {
  final rxList =
      ref.watch(elderPrescriptionsStreamProvider).asData?.value ?? const [];
  final tasks =
      ref.watch(elderVolunteerTasksStreamProvider).asData?.value ?? const [];

  var count = rxList.where((r) => r.isPendingVerification).length;
  count += rxList
      .where(
        (r) =>
            r.isManageablePrescription &&
            r.refillStatus == RefillStatus.outOfStock,
      )
      .length;

  for (final task in tasks) {
    if (task.status != VolunteerTaskStatus.active) continue;
    PrescriptionRecord? rx;
    for (final r in rxList) {
      if (r.id == task.id) {
        rx = r;
        break;
      }
    }
    if (rx == null || !rx.isActive) count++;
  }
  return count;
});

/// 長輩是否仍有「待志工確認」狀態（含 prescriptions 列 + 任務已 active 但藥單未同步）。
///
/// 供 [HealthPage] 橫幅與 [NotificationCenterPage] 共用，避免兩邊判斷不一致。
bool elderHasPendingVerification({
  required List<PrescriptionRecord> prescriptions,
  required List<VolunteerTask> tasks,
}) {
  if (prescriptions.any((r) => r.isPendingVerification)) return true;

  for (final task in tasks) {
    if (task.status != VolunteerTaskStatus.active) continue;
    PrescriptionRecord? rx;
    for (final r in prescriptions) {
      if (r.id == task.id) {
        rx = r;
        break;
      }
    }
    if (rx == null || !rx.isActive) return true;
  }
  return false;
}

/// 啟動長輩端同步：比對 `volunteer_tasks.active` 與 `prescriptions`，補寫 active + 排提醒。
///
/// 在 [HomePage] / [HealthPage] `ref.watch` 即可常駐；`fireImmediately` 處理冷啟動漏同步。
final elderPrescriptionSyncProvider = Provider.autoDispose<void>((ref) {
  ref.watch(authStateChangesProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;

  Future<void> run() async {
    final tasks =
        ref.read(elderVolunteerTasksStreamProvider).asData?.value ?? const [];
    if (tasks.isEmpty) return;

    final rxList =
        ref.read(elderPrescriptionsStreamProvider).asData?.value ?? const [];
    await syncVolunteerTasksToPrescriptions(
      ref: ref,
      tasks: tasks,
      prescriptions: rxList,
    );
  }

  ref.listen<AsyncValue<List<VolunteerTask>>>(
    elderVolunteerTasksStreamProvider,
    (_, next) {
      if (next.hasValue) unawaited(run());
    },
    fireImmediately: true,
  );

  ref.listen<AsyncValue<List<PrescriptionRecord>>>(
    elderPrescriptionsStreamProvider,
    (_, next) {
      if (next.hasValue) {
        unawaited(run());
        unawaited(
          ref
              .read(prescriptionRepositoryProvider)
              .cleanupHiddenVisionPrescriptions(next.requireValue),
        );
      }
    },
    fireImmediately: true,
  );
});

/// 將所有 `active` 志工任務同步到 `prescriptions`（長輩 JWT，可寫自己的列）。
Future<void> syncVolunteerTasksToPrescriptions({
  required Ref ref,
  required List<VolunteerTask> tasks,
  required List<PrescriptionRecord> prescriptions,
}) async {
  final repo = ref.read(prescriptionRepositoryProvider);
  final rxById = {for (final r in prescriptions) r.id: r};

  for (final task in tasks) {
    if (task.status != VolunteerTaskStatus.active) continue;
    if (task.takeMedicineTimes.isEmpty && task.pickupDate == null) continue;

    final existing = rxById[task.id] ?? await repo.fetchById(task.id);
    final needsSync = existing == null ||
        existing.status != 'active' ||
        !_listsEqual(existing.takeMedicineTimes, task.takeMedicineTimes);

    if (!needsSync) continue;

    try {
      await repo.activateFromVolunteerTask(
        id: task.id,
        userId: task.elderId,
        hospitalName: task.hospitalName,
        pickupDate: task.pickupDate ?? DateTime.now(),
        takeMedicineTimes: task.takeMedicineTimes,
      );

      if (task.takeMedicineTimes.isNotEmpty) {
        await NotificationService.instance.schedulePrescriptionReminders(
          prescriptionId: task.id,
          takeMedicineTimes: task.takeMedicineTimes,
        );
      } else {
        // 時段被志工清空：主動取消舊的本機鬧鐘，否則殘留提醒會繼續叮咚。
        await NotificationService.instance
            .cancelRemindersByPrescriptionId(task.id);
      }

      ref.read(elderVolunteerConfirmSnackProvider.notifier).notifyTask(task);
      ref.invalidate(activePrescriptionsProvider);
    } catch (e, st) {
      // ignore: avoid_print
      print('[ElderPrescriptionSync] sync ${task.id} failed: $e\n$st');
    }
  }
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}
