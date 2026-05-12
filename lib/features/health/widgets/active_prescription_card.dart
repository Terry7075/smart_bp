import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notification_service.dart';
import '../../prescription/prescription_models.dart';
import '../../prescription/prescription_provider.dart';

/// 單張「使用中」藥單卡片（領藥倒數、四時段圖示、停用、今日打卡）。
class ActivePrescriptionCard extends ConsumerWidget {
  const ActivePrescriptionCard({
    super.key,
    required this.record,
  });

  final PrescriptionRecord record;

  static const Color _forestGreen = Color(0xFF1B5E20);
  static const Color _warnOrange = Color(0xFFE65100);
  static const Color _dangerRed = Color(0xFFC62828);
  static const Color _primaryGreen = Color(0xFF2E7D32);

  static final Set<String> _morningTargets =
      _normalizeTimeSet(const {'08:00', '09:00'});
  static final Set<String> _noonTargets =
      _normalizeTimeSet(const {'11:30', '13:00'});
  static final Set<String> _eveningTargets =
      _normalizeTimeSet(const {'18:00', '19:00'});
  static final Set<String> _bedtimeTargets =
      _normalizeTimeSet(const {'22:00'});

  static Set<String> _normalizeTimeSet(Set<String> raw) {
    return raw.map(_normalizeTimeLabel).toSet();
  }

  /// 將 `8:00`、`08:0` 等 normalize 成 `HH:mm` 以利與 OCR／志工勾選比對。
  static String _normalizeTimeLabel(String raw) {
    final trimmed = raw.trim();
    final idx = trimmed.indexOf(':');
    if (idx <= 0 || idx >= trimmed.length - 1) return trimmed;
    final h = int.tryParse(trimmed.substring(0, idx)) ?? 0;
    final m = int.tryParse(trimmed.substring(idx + 1)) ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Set<String> get _userNormalizedTimes =>
      record.takeMedicineTimes.map(_normalizeTimeLabel).toSet();

  bool _slotActive(Set<String> targets) =>
      _userNormalizedTimes.any(targets.contains);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (record.hospitalName?.trim().isNotEmpty ?? false)
        ? '🏥 ${record.hospitalName!.trim()} 處方籤'
        : '🏥 藥單 ${record.id.substring(0, 8)}… 處方籤';

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _confirmDeactivate(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '🗑️ 停用',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _pickupSection(record),
            const SizedBox(height: 18),
            const Text(
              '服藥時段',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SlotTile(
                    emoji: '☀️',
                    label: '早上',
                    times: '08:00／09:00',
                    active: _slotActive(_morningTargets),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SlotTile(
                    emoji: '🕛',
                    label: '中午',
                    times: '11:30／13:00',
                    active: _slotActive(_noonTargets),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SlotTile(
                    emoji: '🌙',
                    label: '晚上',
                    times: '18:00／19:00',
                    active: _slotActive(_eveningTargets),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SlotTile(
                    emoji: '🛏️',
                    label: '睡前',
                    times: '22:00',
                    active: _slotActive(_bedtimeTargets),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _logToday(context, ref),
                child: const Text(
                  '✅ 記錄今日已吃藥',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupSection(PrescriptionRecord record) {
    final pickup = record.pickupDate;
    if (pickup == null) {
      return const Text(
        '📅 領藥日：尚未設定',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      );
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final pickupOnly =
        DateTime(pickup.year, pickup.month, pickup.day);
    final diff = pickupOnly.difference(todayOnly).inDays;

    Color color;
    String extra;
    if (diff > 7) {
      color = _forestGreen;
      extra = '';
    } else if (diff >= 3) {
      color = _warnOrange;
      extra = '\n🔔 記得準備領藥喔';
    } else {
      color = _dangerRed;
      extra = '\n⚠️ 藥快沒了！請找志工代領';
    }

    final dateStr =
        '${pickup.year} 年 ${pickup.month} 月 ${pickup.day} 日';

    return Text(
      '📅 距離下次領藥還有 $diff 天（$dateStr）$extra',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: color,
        height: 1.45,
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '確定停用這張藥單？',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '會關掉這張藥單的所有鬧鐘，並將狀態設為停用。',
          style: TextStyle(fontSize: 19, height: 1.45, fontWeight: FontWeight.w600),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '先不要',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              minimumSize: const Size(120, 48),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '確定停用',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    await NotificationService.instance.cancelRemindersByPrescriptionId(
      record.id,
    );

    try {
      await ref.read(prescriptionRepositoryProvider).setCancelled(record.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
          content: Text(
            '資料庫更新失敗：$e',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    ref.invalidate(activePrescriptionsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _primaryGreen,
        duration: Duration(seconds: 4),
        content: Text(
          '已停用這張藥單的提醒。',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _logToday(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(prescriptionRepositoryProvider).insertMedicationLog(
            prescriptionId: record.id,
          );
      ref.invalidate(activePrescriptionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _primaryGreen,
          duration: Duration(seconds: 4),
          content: Text(
            '✅ 紀錄成功！您今天真棒！',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
          content: Text(
            '紀錄失敗：$e',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.emoji,
    required this.label,
    required this.times,
    required this.active,
  });

  final String emoji;
  final String label;
  final String times;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: active ? Colors.black87 : Colors.grey.withValues(alpha: 0.3),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Colors.black26 : Colors.grey.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: active ? 26 : 22)),
            const SizedBox(height: 6),
            Text(label, style: baseStyle, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              times,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
