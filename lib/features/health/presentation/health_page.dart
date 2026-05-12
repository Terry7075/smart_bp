import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/active_prescription_card.dart';

/// 長輩「健康」分頁：以 [StreamBuilder] 監聽 `prescriptions`（依 `created_at` 降冪已於 repo 端排序）。
class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);

  String? _streamUserId;
  Stream<List<PrescriptionRecord>>? _prescriptionsStream;

  void _ensurePrescriptionsStream(String userId) {
    if (_streamUserId == userId && _prescriptionsStream != null) return;
    _streamUserId = userId;
    _prescriptionsStream = ref
        .read(prescriptionRepositoryProvider)
        .watchPrescriptionsForUser(userId);
  }

  void _retryStream() {
    final uid = _streamUserId;
    if (uid == null) return;
    setState(() {
      _prescriptionsStream =
          ref.read(prescriptionRepositoryProvider).watchPrescriptionsForUser(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateChangesProvider);
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _prescriptionsStream = null;
      _streamUserId = null;
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

    _ensurePrescriptionsStream(user.id);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<PrescriptionRecord>>(
            stream: _prescriptionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
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
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: Color(0xFFC62828)),
                        const SizedBox(height: 16),
                        Text(
                          '讀取藥單時發生問題：\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _retryStream,
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
                );
              }

              final list = snapshot.data ?? const <PrescriptionRecord>[];
              final hasPending =
                  list.any((r) => r.status == 'pending_verification');
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
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => context.push('/health-scan'),
                child: const Text(
                  '📷 掃描新藥單',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
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
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '✅ 身體很健康喔！目前沒有吃藥提醒',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 72,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onScan,
                child: const Text(
                  '📷 掃描藥單',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
