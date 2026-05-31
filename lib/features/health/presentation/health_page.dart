import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/prescription/elder_prescription_sync.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/active_prescription_card.dart';

/// 長輩「健康」分頁：監聽 `prescriptions` Realtime + 自動補同步志工確認結果。
class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  static const Color _primaryGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    ref.watch(elderPrescriptionSyncProvider);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '請先登入',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final asyncList = ref.watch(elderPrescriptionsStreamProvider);
    final asyncTasks = ref.watch(elderVolunteerTasksStreamProvider);

    return Column(
      children: [
        Expanded(
          child: asyncList.when(
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      color: _primaryGreen,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '正在讀取藥單…',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: Color(0xFFC62828)),
                    const SizedBox(height: 16),
                    Text(
                      '讀取藥單時發生問題：\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(elderPrescriptionsStreamProvider),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        minimumSize: const Size(200, 52),
                      ),
                      child: const Text(
                        '再試一次',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            data: (list) => asyncTasks.when(
              loading: () => _HealthPrescriptionList(
                list: list,
                tasks: const [],
                tasksReady: false,
              ),
              error: (_, _) => _HealthPrescriptionList(
                list: list,
                tasks: const [],
                tasksReady: true,
              ),
              data: (tasks) => _HealthPrescriptionList(
                list: list,
                tasks: tasks,
                tasksReady: true,
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/health-scan'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.document_scanner_rounded, size: 28),
                label: const Text(
                  '掃描新藥單',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthPrescriptionList extends StatelessWidget {
  const _HealthPrescriptionList({
    required this.list,
    required this.tasks,
    required this.tasksReady,
  });

  final List<PrescriptionRecord> list;
  final List<VolunteerTask> tasks;

  /// volunteer_tasks stream 是否已就緒（loading 時先不顯示待審橫幅，避免閃爍）。
  final bool tasksReady;

  @override
  Widget build(BuildContext context) {
    final hasPending = tasksReady &&
        elderHasPendingVerification(
          prescriptions: list,
          tasks: tasks,
        );
    final active =
        list.where((r) => r.status == 'active').toList(growable: false);
    final hasActive = active.isNotEmpty;
    final showEmpty = !hasPending && !hasActive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        if (hasPending) ...[
          const _VolunteerPendingBanner(),
          const SizedBox(height: 16),
        ],
        if (showEmpty) ...[
          _EmptyHealthPrompt(onScan: () => context.push('/health-scan')),
          const SizedBox(height: 20),
        ],
        if (hasActive) ...[
          const Text(
            '💊 使用中的藥單',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final rx in active) ...[
            ActivePrescriptionCard(record: rx),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}

class _VolunteerPendingBanner extends StatelessWidget {
  const _VolunteerPendingBanner();

  static const Color _yellowBg = Color(0xFFFFFDE7);
  static const Color _yellowBorder = Color(0xFFF9A825);

  @override
  Widget build(BuildContext context) {
    final amberText = Colors.amber.shade900;

    return Card(
      color: _yellowBg,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _yellowBorder, width: 2),
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
            Text(
              '請耐心等候，村辦公室確認完畢後會立刻通知您！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.brown.shade800,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHealthPrompt extends StatelessWidget {
  const _EmptyHealthPrompt({required this.onScan});

  final VoidCallback onScan;

  static const Color _primaryGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '還沒有使用中的藥單',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '您可以掃描藥袋，或請志工協助建立藥單。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: _primaryGreen,
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text(
                '開始掃描藥單',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
