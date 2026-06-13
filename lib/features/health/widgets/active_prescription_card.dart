import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notification_service.dart';
import '../../medication/widgets/medication_identity_card.dart';
import '../../prescription/prescription_models.dart';
import '../../prescription/prescription_provider.dart';

/// 單張「使用中」藥單卡片（志工代領狀態、四時段圖示、刪除、今日打卡）。
class ActivePrescriptionCard extends ConsumerWidget {
  const ActivePrescriptionCard({super.key, required this.record});

  final PrescriptionRecord record;

  static const Color _primaryGreen = Color(0xFF2E7D32);

  /// 將 `8:00`、`08:0` 等 normalize 成 `HH:mm`，順便丟掉空字串。
  static String _normalizeTimeLabel(String raw) {
    final trimmed = raw.trim();
    final idx = trimmed.indexOf(':');
    if (idx <= 0 || idx >= trimmed.length - 1) return trimmed;
    final h = int.tryParse(trimmed.substring(0, idx)) ?? 0;
    final m = int.tryParse(trimmed.substring(idx + 1)) ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 把 `HH:mm` 字串轉成「當日分鐘數」，無法解析回 `null`。
  static int? _slotMinutes(String raw) {
    final t = raw.trim();
    final idx = t.indexOf(':');
    if (idx <= 0) return null;
    final h = int.tryParse(t.substring(0, idx));
    final m = int.tryParse(t.substring(idx + 1));
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// 依「現在時間」挑出該打卡的時段（回傳藥單裡的**原始字串**，以對得上
  /// 通知排程寫進 `medication_logs.slot_time` 的值）。
  ///
  /// 規則：取所有「時間 ≤ 現在」中最晚的一格（當下該吃的那一份）；若現在比
  /// 第一格還早，就回第一格；沒有任何可解析時段則回 `null`（單筆打卡）。
  ///
  /// 這是讓「健康卡片打卡」也能分時段鎖定的關鍵：不帶 slotTime 時打卡頁會
  /// 退化成「今天有打過任何卡」的整日鎖，導致打完早上、中午晚上都被標已打卡。
  static String? _slotForNow(List<String> times, [DateTime? now]) {
    final parsed = <({String raw, int min})>[];
    for (final raw in times) {
      final m = _slotMinutes(raw);
      if (m != null) parsed.add((raw: raw, min: m));
    }
    if (parsed.isEmpty) return null;
    parsed.sort((a, b) => a.min.compareTo(b.min));

    final dt = now ?? DateTime.now();
    final nowMin = dt.hour * 60 + dt.minute;
    ({String raw, int min})? due;
    for (final p in parsed) {
      if (p.min <= nowMin) due = p;
    }
    return (due ?? parsed.first).raw;
  }

  /// 把 `HH:mm` 轉成「一天內的分鐘數」，無效字串 → -1。
  static int _minutesOfDay(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return -1;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return -1;
    if (h < 0 || h > 23 || m < 0 || m > 59) return -1;
    return h * 60 + m;
  }

  /// 取出使用者實際時段中，落在「[start, end)」分鐘區間內的所有時間。
  ///
  /// 為什麼用區間？舊版用「精確比對 08:00/09:00」，OCR 給 07:30 就四個 tile
  /// 全黯淡，看起來像沒設定提醒。改成範圍後，07:30 自然會落入「早上」。
  ///
  /// 跨午夜（如 21:00 到 04:59 算睡前）由 [start] > [end] 觸發。
  List<String> _userTimesInRange({required int start, required int end}) {
    final out = <String>[];
    for (final raw in record.takeMedicineTimes) {
      final norm = _normalizeTimeLabel(raw);
      final m = _minutesOfDay(norm);
      if (m < 0) continue;
      final inRange = start <= end
          ? (m >= start && m < end)
          : (m >= start || m < end);
      if (inRange) out.add(norm);
    }
    out.sort();
    return out;
  }

  /// 用「分鐘區間」定義四個時段。
  ///
  /// - 早上：05:00 ≤ t < 11:00
  /// - 中午：11:00 ≤ t < 15:00
  /// - 晚上：15:00 ≤ t < 21:00
  /// - 睡前：21:00 ≤ t 或 t < 05:00（跨午夜）
  ///
  /// 任何使用者時段必落入恰好一個區間，不會「兩邊都不亮」也不會「重複亮」。
  static const int _morningStart = 5 * 60;
  static const int _noonStart = 11 * 60;
  static const int _eveningStart = 15 * 60;
  static const int _bedtimeStart = 21 * 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (record.hospitalName?.trim().isNotEmpty ?? false)
        ? '🏥 ${record.hospitalName!.trim()} 處方籤'
        : '🏥 藥單 ${record.id.substring(0, 8)}… 處方籤';
    final refillBanner = _refillBanner(record);

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
                  onPressed: () => _confirmDelete(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '🗑️ 刪除',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (refillBanner != null) ...[
              const SizedBox(height: 12),
              refillBanner,
            ],
            const SizedBox(height: 16),
            MedicationIdentityCard(record: record, compact: true),
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
            Builder(
              builder: (_) {
                final morning = _userTimesInRange(
                  start: _morningStart,
                  end: _noonStart,
                );
                final noon = _userTimesInRange(
                  start: _noonStart,
                  end: _eveningStart,
                );
                final evening = _userTimesInRange(
                  start: _eveningStart,
                  end: _bedtimeStart,
                );
                final bedtime = _userTimesInRange(
                  start: _bedtimeStart,
                  end: _morningStart,
                );
                return Row(
                  children: [
                    Expanded(
                      child: _SlotTile(
                        emoji: '☀️',
                        label: '早上',
                        userTimes: morning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SlotTile(
                        emoji: '🕛',
                        label: '中午',
                        userTimes: noon,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SlotTile(
                        emoji: '🌙',
                        label: '晚上',
                        userTimes: evening,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SlotTile(
                        emoji: '🛏️',
                        label: '睡前',
                        userTimes: bedtime,
                      ),
                    ),
                  ],
                );
              },
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
                onPressed: () => _openCheckin(context),
                child: const Text(
                  '✅ 記錄今日已吃藥（看圖認藥）',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _refillBanner(PrescriptionRecord record) {
    final message = switch (record.refillStatus) {
      RefillStatus.collecting => '🛵 志工正在幫您代領下個月的藥，請安心等候！',
      RefillStatus.outOfStock => '⚠️ 藥局目前缺藥調貨中，志工會持續幫您追蹤！',
      _ => null,
    };
    if (message == null) return null;

    final isCollecting = record.refillStatus == RefillStatus.collecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCollecting ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCollecting
              ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
              : const Color(0xFFE65100).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          height: 1.4,
          color: isCollecting
              ? const Color(0xFF1B5E20)
              : const Color(0xFFE65100),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final hasVolunteerRefill = RefillStatus.shouldRetainVolunteerRefillOnDelete(
      record.refillStatus,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '確定刪除這張藥單？',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          hasVolunteerRefill
              ? '會關掉這張藥單的所有鬧鐘，並把它從清單上拿掉。\n'
                    '已經吃藥的打卡紀錄也會一併移除，刪除後無法復原。\n\n'
                    '您已申請志工代領：志工端仍會看到提醒，'
                    '請主動告知志工或請志工再次確認。'
              : '會關掉這張藥單的所有鬧鐘，並把它從清單上拿掉。\n'
                    '已經吃藥的打卡紀錄也會一併移除，刪除後無法復原。',
          style: const TextStyle(
            fontSize: 19,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
              '確定刪除',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    // 先取消本地排程的提醒鬧鐘，避免「DB 已刪除但本機還會跳通知」的鬼點子。
    await NotificationService.instance.cancelRemindersByPrescriptionId(
      record.id,
    );

    try {
      await ref
          .read(prescriptionRepositoryProvider)
          .deletePrescription(record.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
          content: Text(
            e is StateError ? e.message : '刪除失敗：$e',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    // Realtime 有時 DELETE 事件會延遲；主動 invalidate 讓清單立刻刷新。
    // 先確認 widget 還在（刪除 await 期間使用者可能已離開頁面），
    // 否則對已 dispose 的 ref 操作會丟例外。
    if (!context.mounted) return;
    ref.invalidate(elderPrescriptionsStreamProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: _primaryGreen,
        duration: Duration(seconds: 4),
        content: Text(
          '已刪除這張藥單。',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _openCheckin(BuildContext context) {
    final enc = Uri.encodeComponent(record.id);
    // 帶上「當下該吃的時段」，讓打卡頁能分時段鎖定（不再整日鎖）。
    final slot = _slotForNow(record.takeMedicineTimes);
    final slotQ = slot != null ? '&slotTime=${Uri.encodeComponent(slot)}' : '';
    context.push('/medication-checkin?prescriptionId=$enc$slotQ');
  }
}

/// 單一時段格：顯示「使用者實際時間」而非寫死的 08:00／09:00。
///
/// - 有時間 → emoji 變亮、列出實際 HH:mm（多個用斜線分隔）
/// - 無時間 → 顯示「—」，並把整塊調淡，讓長輩一眼看出這個時段不吃藥
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.emoji,
    required this.label,
    required this.userTimes,
  });

  final String emoji;
  final String label;
  final List<String> userTimes;

  @override
  Widget build(BuildContext context) {
    final active = userTimes.isNotEmpty;
    final baseStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: active ? Colors.black87 : Colors.grey.withValues(alpha: 0.3),
    );
    // 多個時間用 `／` 分隔（保留與 OCR 提示頁同樣的全形斜線視覺）。
    final timesText = active ? userTimes.join('／') : '—';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35)
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
              timesText,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
