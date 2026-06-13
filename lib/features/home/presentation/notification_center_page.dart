import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prescription/elder_prescription_sync.dart';
import '../../prescription/prescription_models.dart';
import '../../prescription/prescription_provider.dart';
import '../../volunteer/volunteer_task.dart';

/// 長輩端「系統通知」：待審核藥單、缺藥調貨等狀態集中顯示。
class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key});

  static const Color _waitYellowBg = Color(0xFFFFFDE7);
  static const Color _waitYellowBorder = Color(0xFFF9A825);
  static const Color _stockOrangeBg = Color(0xFFFFF3E0);
  static const Color _stockOrangeBorder = Color(0xFFE65100);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(elderPrescriptionSyncProvider);
    final asyncList = ref.watch(elderPrescriptionsStreamProvider);
    final asyncTasks = ref.watch(elderVolunteerTasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🔔 系統通知',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '讀取通知失敗：$e',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        data: (list) => asyncTasks.when(
          loading: () => _NotificationBody(list: list, tasks: const []),
          error: (_, _) => _NotificationBody(list: list, tasks: const []),
          data: (tasks) => _NotificationBody(list: list, tasks: tasks),
        ),
      ),
    );
  }
}

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({
    required this.list,
    required this.tasks,
  });

  final List<PrescriptionRecord> list;
  final List<VolunteerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final pending = list
        .where((r) => r.status == 'pending_verification')
        .toList();

    // 志工已按確認但 prescriptions 尚未同步時，仍顯示等待卡。
    for (final task in tasks) {
      if (task.status != VolunteerTaskStatus.active) continue;
      if (pending.any((r) => r.id == task.id)) continue;
      final rx = _findRx(task.id);
      if (rx == null || !rx.isActive) {
        pending.add(
          PrescriptionRecord(
            id: task.id,
            userId: task.elderId,
            hospitalName: task.hospitalName,
            status: 'pending_verification',
            source: 'volunteer',
            createdAt: task.createdAt,
          ),
        );
      }
    }

    final outOfStock = list
        .where(
          (r) =>
              r.isManageablePrescription &&
              r.refillStatus == RefillStatus.outOfStock,
        )
        .toList();
    final recentlyConfirmed = list
        .where((r) => _isVolunteerConfirmed(r, tasks))
        .toList();

    if (pending.isEmpty && outOfStock.isEmpty && recentlyConfirmed.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '✅ 目前沒有新的通知喔！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final rx in pending) ...[
          _PendingVerificationCard(record: rx),
          const SizedBox(height: 14),
        ],
        for (final rx in recentlyConfirmed) ...[
          _VolunteerConfirmedCard(record: rx),
          const SizedBox(height: 14),
        ],
        for (final rx in outOfStock) ...[
          _OutOfStockCard(record: rx),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  PrescriptionRecord? _findRx(String id) {
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 「志工已幫您確認」屬於一次性通知，只在確認後一小段時間內顯示，
  /// 之後長輩到「健康」分頁就看得到使用中藥單，不需通知中心一直留著。
  static const Duration _confirmedNoticeWindow = Duration(days: 3);

  /// 志工任務已 active，且藥單已同步為 active（有吃藥時段），且仍在通知視窗內。
  static bool _isVolunteerConfirmed(
    PrescriptionRecord r,
    List<VolunteerTask> tasks,
  ) {
    if (!r.isActive || r.source != 'volunteer') return false;
    if (r.takeMedicineTimes.isEmpty) return false;
    final age = DateTime.now().difference(r.createdAt);
    if (age > _confirmedNoticeWindow) return false;
    return tasks.any(
      (t) => t.id == r.id && t.status == VolunteerTaskStatus.active,
    );
  }
}

class _VolunteerConfirmedCard extends StatelessWidget {
  const _VolunteerConfirmedCard({required this.record});

  final PrescriptionRecord record;

  static const Color _green = Color(0xFF2E7D32);
  static const Color _greenBg = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final hospital = record.hospitalName?.trim();

    return Card(
      color: _greenBg,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _green.withValues(alpha: 0.45), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ 志工已幫您確認藥單！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _green,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '已設好每日吃藥提醒，請到「健康」分頁查看。',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
                height: 1.45,
              ),
            ),
            if (hospital != null && hospital.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '🏥 $hospital',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF33691E),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingVerificationCard extends StatelessWidget {
  const _PendingVerificationCard({required this.record});

  final PrescriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final amberText = Colors.amber.shade900;
    final hospital = record.hospitalName?.trim();

    return Card(
      color: NotificationCenterPage._waitYellowBg,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: NotificationCenterPage._waitYellowBorder,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: amberText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⏳ 志工正在幫您看藥單中...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: amberText,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '請耐心等候，村辦公室確認完畢後會立刻通知您！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
            if (hospital != null && hospital.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '🏥 $hospital',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: amberText.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutOfStockCard extends StatelessWidget {
  const _OutOfStockCard({required this.record});

  final PrescriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final hospital = record.hospitalName?.trim();

    return Card(
      color: NotificationCenterPage._stockOrangeBg,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: NotificationCenterPage._stockOrangeBorder.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ 藥局目前缺藥調貨中，志工會持續幫您追蹤！',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: NotificationCenterPage._stockOrangeBorder,
                height: 1.35,
              ),
            ),
            if (hospital != null && hospital.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '🏥 $hospital',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBF360C),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
