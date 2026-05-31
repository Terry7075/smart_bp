// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../prescription/prescription_models.dart';
import '../prescription/prescription_provider.dart';
import 'volunteer_batch_refill_provider.dart';

const String _kPrescriptionPhotosBucket = 'prescription-photos';
const int _kPrescriptionPhotoSignedUrlSeconds = 60 * 60;

/// 志工「🛵 批次代領任務」分頁。
///
/// UI 原則：
/// - 卡片以「同一個領藥日」分群，志工出門時可一眼看當天有幾份要代領
/// - 卡片內每位長輩列點擊 → 開啟「藥單詳細資訊」bottom sheet
///   讓志工能再次核對藥名、醫療機構與服藥時段
/// - 「已收健保卡」checkbox 採 optimistic update：按下立刻反映在 UI，
///   不必等 Supabase Realtime 回傳；避免之前「勾了沒反應、要重刷頁面」的問題
class VolunteerBatchRefillTab extends ConsumerWidget {
  const VolunteerBatchRefillTab({super.key});

  static const Color _volunteerBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(volunteerBatchRefillGroupsProvider);

    return asyncGroups.when(
      loading: () => const _BatchLoadingView(),
      error: (e, _) => _BatchErrorView(
        error: e,
        onRetry: () => ref.invalidate(volunteerBatchRefillGroupsProvider),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const _BatchEmptyView();
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: groups.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _BatchRefillGroupCard(group: groups[index]),
          ),
        );
      },
    );
  }
}

class _BatchLoadingView extends StatelessWidget {
  const _BatchLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: CircularProgressIndicator(
            strokeWidth: 6,
            color: VolunteerBatchRefillTab._volunteerBlue,
          ),
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            '正在整理 10 天內需代領的藥單…',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: VolunteerBatchRefillTab._volunteerBlue,
            ),
          ),
        ),
      ],
    );
  }
}

class _BatchErrorView extends StatelessWidget {
  const _BatchErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 72, color: Color(0xFFBF360C)),
        const SizedBox(height: 16),
        Text(
          '讀取代領任務失敗：\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBF360C),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: VolunteerBatchRefillTab._volunteerBlue,
            minimumSize: const Size(double.infinity, 56),
          ),
          child: const Text(
            '重新讀取',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _BatchEmptyView extends StatelessWidget {
  const _BatchEmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.check_circle_outline,
            size: 88, color: VolunteerBatchRefillTab._volunteerBlue),
        SizedBox(height: 20),
        Text(
          '目前沒有 10 天內\n需批次代領的藥單。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: VolunteerBatchRefillTab._volunteerBlue,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _BatchRefillGroupCard extends ConsumerStatefulWidget {
  const _BatchRefillGroupCard({required this.group});

  final BatchRefillGroup group;

  @override
  ConsumerState<_BatchRefillGroupCard> createState() =>
      _BatchRefillGroupCardState();
}

class _BatchRefillGroupCardState extends ConsumerState<_BatchRefillGroupCard> {
  bool _busy = false;

  /// 勾選 optimistic override：`prescriptionId → hasHealthCard`。
  ///
  /// 為什麼需要 override 而不是直接依 stream 資料？
  /// - Supabase Realtime 對 UPDATE 偶有 0.5~3 秒延遲；如果直接讀 stream，
  ///   志工會看到「我明明勾了，怎麼還是空的 → 再勾一次」的鬼打牆。
  /// - 按下後立刻寫進這個 map，build 優先讀它；等到 stream 把 DB 新值
  ///   送進來、與 override 一致時，[didUpdateWidget] 會把 override 清掉。
  final Map<String, bool> _healthCardOverrides = {};

  @override
  void didUpdateWidget(_BatchRefillGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當新進來的 group 資料已經與 local override 一致，就移除 override，
    // 讓資料源回到單一真相（stream）。
    if (_healthCardOverrides.isEmpty) return;
    final toClear = <String>[];
    for (final item in widget.group.items) {
      final id = item.prescription.id;
      final override = _healthCardOverrides[id];
      if (override != null && override == item.prescription.hasHealthCard) {
        toClear.add(id);
      }
    }
    if (toClear.isNotEmpty) {
      setState(() {
        for (final id in toClear) {
          _healthCardOverrides.remove(id);
        }
      });
    }
  }

  bool _effectiveHasHealthCard(PrescriptionRecord rx) {
    return _healthCardOverrides[rx.id] ?? rx.hasHealthCard;
  }

  /// 所有勾選必須完成才能解鎖底下兩顆動作鈕；這個 getter 把 override 算進去，
  /// 避免「勾完最後一個，按鈕還沒亮」的等待感。
  bool get _allHealthCardsCollected {
    if (widget.group.items.isEmpty) return false;
    return widget.group.items.every(
      (item) => _effectiveHasHealthCard(item.prescription),
    );
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onHealthCardChanged(
    PrescriptionRecord rx,
    bool? checked,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(prescriptionRepositoryProvider);
    final newValue = checked == true;

    // --- Optimistic update：立刻反映到畫面 ---
    final previous = _healthCardOverrides[rx.id];
    setState(() => _healthCardOverrides[rx.id] = newValue);

    try {
      await repo.setRefillHealthCard(
        prescriptionId: rx.id,
        hasHealthCard: newValue,
        refillStatus: newValue ? RefillStatus.collecting : RefillStatus.none,
      );
    } catch (e) {
      print('[BatchRefill] health card update error: $e');
      // --- 失敗回滾：把畫面拉回先前狀態，並提示志工 ---
      if (mounted) {
        setState(() {
          if (previous == null) {
            _healthCardOverrides.remove(rx.id);
          } else {
            _healthCardOverrides[rx.id] = previous;
          }
        });
      }
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              '更新失敗：$e',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
    }
  }

  Future<void> _completeBatch() async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(prescriptionRepositoryProvider);
    final list =
        widget.group.items.map((e) => e.prescription).toList(growable: false);

    await _withBusy(() async {
      try {
        await repo.completeBatchRefill(list);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 5),
            content: Text(
              '✅ 已展延領藥日並歸還證件紀錄，長輩端會看到更新！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } catch (e) {
        print('[BatchRefill] complete error: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              '領藥完成更新失敗：$e',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    });
  }

  Future<void> _reportOutOfStock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '確定回報缺藥？',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '確定回報缺藥？系統將通知長輩正在調貨中。',
          style: TextStyle(fontSize: 18, height: 1.45, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先不要', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '確定回報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ids = widget.group.items.map((e) => e.prescription.id).toList();

    await _withBusy(() async {
      try {
        await ref
            .read(prescriptionRepositoryProvider)
            .reportBatchOutOfStock(ids);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFE65100),
            duration: Duration(seconds: 5),
            content: Text(
              '⚠️ 已標記為缺藥調貨中，請通知長輩稍候。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } catch (e) {
        print('[BatchRefill] out of stock error: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              '回報失敗：$e',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    });
  }

  void _openElderDetail(BatchRefillElderItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ElderRefillDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final actionsEnabled = _allHealthCardsCollected && !_busy;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 卡片標題：以「領藥日」為單位 ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.event_available,
                    size: 32, color: VolunteerBatchRefillTab._volunteerBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📅 ${group.titleDisplay}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '共 ${group.count} 份藥單需代領',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final item in group.items) ...[
              _ElderRefillRow(
                item: item,
                hasHealthCard: _effectiveHasHealthCard(item.prescription),
                onHealthCardChanged: (v) =>
                    _onHealthCardChanged(item.prescription, v),
                onTap: () => _openElderDetail(item),
              ),
              const SizedBox(height: 8),
            ],
            if (!_allHealthCardsCollected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '請先勾選每一位長輩的「已收到健保卡與慢箋正本」，\n才能執行領藥完成或缺藥回報。',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: actionsEnabled ? _completeBatch : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '✅ 領藥完成並歸還',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: actionsEnabled ? _reportOutOfStock : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                      child: const Text(
                        '⚠️ 藥局缺藥回報',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ElderRefillRow extends StatelessWidget {
  const _ElderRefillRow({
    required this.item,
    required this.hasHealthCard,
    required this.onHealthCardChanged,
    required this.onTap,
  });

  final BatchRefillElderItem item;

  /// 由父層算好的「目前顯示用」勾選狀態（含 optimistic override）。
  final bool hasHealthCard;
  final ValueChanged<bool?> onHealthCardChanged;

  /// 整列點擊 → 開啟詳細資訊 sheet。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rx = item.prescription;
    final status = rx.refillStatus;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.elderName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (status != RefillStatus.none)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == RefillStatus.outOfStock
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        RefillStatus.label(status),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: status == RefillStatus.outOfStock
                              ? const Color(0xFFC62828)
                              : const Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 24, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '🏥 ${item.hospitalDisplay}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (rx.displayMedicationName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '💊 ${rx.displayMedicationName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
              // CheckboxListTile 自己會吃 onTap，所以勾選不會觸發外層的 InkWell。
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: hasHealthCard,
                onChanged: onHealthCardChanged,
                title: const Text(
                  '證件確認：已收到健保卡與慢箋正本',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 點擊長輩列後彈出的「藥單詳細資訊」面板。
///
/// 目的：志工出門前 / 領藥當下能快速核對：
/// - 長輩姓名 + 醫療機構 + 領藥日
/// - 藥名（合併 OCR 抓到的多個）
/// - 服藥時段
/// - 外觀提示（顏色／形狀）
/// - Vision OCR 抓出的 `medications_detail` JSON 細項（如有）
class _ElderRefillDetailSheet extends StatelessWidget {
  const _ElderRefillDetailSheet({required this.item});

  final BatchRefillElderItem item;

  static const Color _ink = Color(0xFF263238);
  static const Color _muted = Color(0xFF607D8B);

  String _formatPickup(DateTime? d) {
    if (d == null) return '（未設定）';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final rx = item.prescription;
    final times = rx.takeMedicineTimes;
    final meds = rx.medicationsDetail;
    final pillHint = rx.displayPillHint;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Sheet 頂部抓桿 ---
              Center(
                child: Container(
                  width: 56,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.person,
                      size: 32, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.elderName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailField(
                icon: Icons.local_hospital,
                label: '醫療機構',
                value: item.hospitalDisplay,
              ),
              _DetailField(
                icon: Icons.event,
                label: '預計領藥日',
                value: _formatPickup(rx.pickupDate),
              ),
              _DetailField(
                icon: Icons.medication,
                label: '藥品',
                value: rx.displayMedicationName ?? '（藥袋上沒抓到藥名）',
              ),
              if (pillHint.isNotEmpty)
                _DetailField(
                  icon: Icons.palette_outlined,
                  label: '外觀提示',
                  value: pillHint,
                ),
              if (times.isNotEmpty)
                _DetailField(
                  icon: Icons.alarm,
                  label: '服藥時段',
                  value: times.join(' / '),
                ),
              if (rx.medicationDays != null)
                _DetailField(
                  icon: Icons.calendar_view_month,
                  label: '本次給藥天數',
                  value: '${rx.medicationDays} 天',
                ),
              if (meds.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '🧾 藥單明細',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                for (final m in meds) _MedicationDetailItem(detail: m),
              ],
              // ── 原始藥單照片 ──────────────────────────────────────────────
              if ((rx.photoStoragePath ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '📷 藥單原始照片',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                _PrescriptionPhotoSection(
                  storagePath: rx.photoStoragePath!,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '關閉',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 22, color: _ElderRefillDetailSheet._muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ElderRefillDetailSheet._muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: _ElderRefillDetailSheet._ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationDetailItem extends StatelessWidget {
  const _MedicationDetailItem({required this.detail});

  final Map<String, dynamic> detail;

  String? _str(Object? raw) {
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final name = _str(detail['name']) ?? '（無藥名）';
    final appearance = _str(detail['appearance']);
    final times = (detail['times'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final special = _str(detail['specialInstructions']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFAED581)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _ElderRefillDetailSheet._ink,
            ),
          ),
          if (appearance != null) ...[
            const SizedBox(height: 4),
            Text(
              '外觀：$appearance',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ElderRefillDetailSheet._muted,
              ),
            ),
          ],
          if (times.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '時段：${times.join(' / ')}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ElderRefillDetailSheet._muted,
              ),
            ),
          ],
          if (special != null) ...[
            const SizedBox(height: 4),
            Text(
              '叮嚀：$special',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE65100),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 藥單原始照片（prescription-photos 私人 bucket → signed URL）
// ─────────────────────────────────────────────────────────────────────────────

class _PrescriptionPhotoSection extends StatefulWidget {
  const _PrescriptionPhotoSection({required this.storagePath});

  final String storagePath;

  @override
  State<_PrescriptionPhotoSection> createState() =>
      _PrescriptionPhotoSectionState();
}

class _PrescriptionPhotoSectionState
    extends State<_PrescriptionPhotoSection> {
  static const Color _blue = Color(0xFF1565C0);

  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _fetchSignedUrl();
  }

  Future<String> _fetchSignedUrl() {
    return Supabase.instance.client.storage
        .from(_kPrescriptionPhotosBucket)
        .createSignedUrl(
          widget.storagePath,
          _kPrescriptionPhotoSignedUrlSeconds,
        );
  }

  void _retry() => setState(() => _urlFuture = _fetchSignedUrl());

  void _openFullscreen(String url) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PrescriptionFullscreenPhoto(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildContent(snapshot),
          ),
        );
      },
    );
  }

  Widget _buildContent(AsyncSnapshot<String> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1565C0)),
              SizedBox(height: 12),
              Text(
                '載入藥單照片中…',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    if (snapshot.hasError || !snapshot.hasData) {
      print('[PrescriptionPhoto] signed URL error: ${snapshot.error}');
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                size: 56, color: Color(0xFFBF360C)),
            const SizedBox(height: 12),
            const Text(
              '照片讀取失敗',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFBF360C),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, color: _blue),
              label: const Text(
                '重新載入',
                style: TextStyle(fontSize: 15, color: _blue),
              ),
            ),
          ],
        ),
      );
    }

    final url = snapshot.data!;
    return InkWell(
      onTap: () => _openFullscreen(url),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: _blue,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('[PrescriptionPhoto] Image.network error: $error');
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        size: 56, color: Color(0xFFBF360C)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, color: _blue),
                      label: const Text('重新載入',
                          style: TextStyle(fontSize: 15, color: _blue)),
                    ),
                  ],
                ),
              );
            },
          ),
          // 提示可點開全螢幕
          Container(
            margin: const EdgeInsets.all(8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '點擊放大',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全螢幕藥單照片：雙指縮放 + 拖曳，方便核對細節。
class _PrescriptionFullscreenPhoto extends StatelessWidget {
  const _PrescriptionFullscreenPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '藥單原始照片',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  '照片讀取失敗',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
