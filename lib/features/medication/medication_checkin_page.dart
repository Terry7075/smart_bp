// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../prescription/prescription_models.dart';
import '../prescription/prescription_provider.dart';
import 'drug_dictionary_service.dart';
import 'widgets/drug_image_section.dart';
import 'widgets/medication_identity_card.dart';

/// 吃藥打卡頁：通常由「吃藥提醒通知」或健康頁藥單卡片開啟。
class MedicationCheckinPage extends ConsumerStatefulWidget {
  const MedicationCheckinPage({
    super.key,
    required this.prescriptionId,
    this.slotTime,
  });

  final String prescriptionId;
  final String? slotTime;

  @override
  ConsumerState<MedicationCheckinPage> createState() =>
      _MedicationCheckinPageState();
}

class _MedicationCheckinPageState extends ConsumerState<MedicationCheckinPage>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF2E7D32);

  bool _submitting = false;
  bool _done = false;
  late AnimationController _celebrate;

  /// 上一次失敗後的 cooldown，避免長輩在「網路抖一下」時連點 5 次→疊 5 個錯誤
  /// SnackBar。失敗後 [_failureCooldown] 內再按只會看到統一的「請稍候再試」提示，
  /// 不會真的再打 DB。同時搭配 [_cooldownTimer]，cooldown 結束時自動 setState
  /// 把大按鈕從灰色解鎖回綠色，不必使用者手動 refresh。
  static const Duration _failureCooldown = Duration(seconds: 3);
  DateTime? _lastFailureAt;
  Timer? _cooldownTimer;

  bool get _inCooldown {
    final at = _lastFailureAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _failureCooldown;
  }

  bool _loadingRx = true;
  PrescriptionRecord? _prescription;
  Future<DrugImageLookup>? _drugImageFuture;

  /// 今日同一張藥單（+ 同一時段，若 URL 有帶）是否已經打過卡。
  /// `true` 時把大按鈕換成「已打過卡」狀態，避免報表被重複 insert 汙染。
  bool _alreadyLoggedToday = false;

  @override
  void initState() {
    super.initState();
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadPrescription();
  }

  Future<void> _loadPrescription() async {
    if (widget.prescriptionId.isEmpty) {
      if (mounted) setState(() => _loadingRx = false);
      return;
    }
    try {
      final repo = ref.read(prescriptionRepositoryProvider);
      // 並行取藥單本體 +「今日是否已打卡」，比依序執行少一個 round-trip。
      final results = await Future.wait<Object?>([
        repo.fetchById(widget.prescriptionId),
        repo.hasLoggedToday(
          prescriptionId: widget.prescriptionId,
          slotTime: widget.slotTime,
        ),
      ]);
      final rx = results[0] as PrescriptionRecord?;
      final alreadyLogged = results[1] as bool;

      if (mounted) {
        final candidates = rx == null
            ? const <String>[]
            : buildDrugLookupCandidates(
                medicationName: rx.medicationName,
                medicationsDetail: rx.medicationsDetail,
              );
        print('[Checkin] drug lookup candidates: $candidates');
        setState(() {
          _prescription = rx;
          _loadingRx = false;
          _alreadyLoggedToday = alreadyLogged;
          // 透過 Riverpod 取共用 singleton，跨頁切回來時可命中內存快取，
          // 不用每次進打卡頁都重打 Supabase。
          _drugImageFuture = candidates.isEmpty
              ? Future<DrugImageLookup>.value(const DrugImageNotFound())
              : ref
                  .read(drugDictionaryServiceProvider)
                  .fetchDrugImageForCandidates(candidates);
        });
      }
    } catch (e) {
      print('[Checkin] load prescription error: $e');
      if (mounted) {
        setState(() {
          _loadingRx = false;
          _drugImageFuture = Future<DrugImageLookup>.value(
            DrugImageLookupFailed('讀取藥單失敗：$e'),
          );
        });
      }
    }
  }

  /// 讓 `DrugImageSection` 的「重新查詢」按鈕呼叫——重打一次藥典查詢、
  /// 同時觸發 [FutureBuilder] 重 build。
  void _retryDrugImageLookup() {
    final rx = _prescription;
    if (rx == null) return;
    final candidates = buildDrugLookupCandidates(
      medicationName: rx.medicationName,
      medicationsDetail: rx.medicationsDetail,
    );
    setState(() {
      _drugImageFuture = candidates.isEmpty
          ? Future<DrugImageLookup>.value(const DrugImageNotFound())
          : ref
              .read(drugDictionaryServiceProvider)
              .fetchDrugImageForCandidates(candidates);
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _celebrate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.prescriptionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text(
            '找不到藥單編號，請從通知點進來打卡。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    // 防呆：UI 在 _alreadyLoggedToday 時就會把大按鈕換掉，但這層守門
    // 確保未來若有別的入口呼叫 _submit 也不會偷偷塞重複紀錄進 DB。
    if (_alreadyLoggedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 4),
          content: Text(
            '✅ 今天這個時段已經打過卡囉，不用再打了。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    // 失敗 cooldown：剛剛失敗過、且還沒過 [_failureCooldown]，連點不再打 DB，
    // 只用同一個「請稍候再試」提示取代原本的詳細錯誤訊息，避免 SnackBar 疊一片。
    if (_inCooldown) {
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFE65100),
          duration: Duration(seconds: 3),
          content: Text(
            '⏳ 剛剛沒打卡成功，請等幾秒再試。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(prescriptionRepositoryProvider).insertMedicationLog(
            prescriptionId: widget.prescriptionId,
            slotTime: widget.slotTime,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
        _alreadyLoggedToday = true;
        _lastFailureAt = null;
      });
      await _celebrate.forward(from: 0);
    } catch (e) {
      print('[Checkin] error: $e');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _lastFailureAt = DateTime.now();
      });
      // cooldown 結束自動 setState 解鎖按鈕；舊 Timer 先取消避免疊單。
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(_failureCooldown, () {
        if (!mounted) return;
        setState(() => _lastFailureAt = null);
      });
      // 先清掉舊的 SnackBar，避免上一次失敗訊息還在底下重疊。
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 5),
          content: Text(
            '打卡失敗：$e\n稍等幾秒系統會解鎖，再按一次。',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel =
        (widget.slotTime != null && widget.slotTime!.isNotEmpty)
            ? widget.slotTime!
            : '';
    final rx = _prescription;
    // 「進到頁面前就已經打過卡」與「在這個 session 剛剛打完卡」都算「已完成」，
    // 都不應再顯示大圓按鈕，避免長輩重複按。
    final showLockedView = _alreadyLoggedToday && !_done;

    final String headlineText;
    final String subtitleText;
    if (_done) {
      headlineText = '🎉 太棒了！';
      subtitleText = '村辦公室看得到您的紀錄喔，繼續保持！';
    } else if (showLockedView) {
      headlineText = '✅ 今天已經打過卡了！';
      subtitleText = slotLabel.isNotEmpty
          ? '您今天 $slotLabel 已經完成打卡，這個時段不用再打囉。'
          : '您今天已經完成打卡，不用再打囉。';
    } else {
      headlineText = '該吃藥囉！';
      subtitleText = '請先看清楚要吃的藥，吃完再按下面大按鈕打卡。';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        toolbarHeight: 72,
        title: const Text(
          '吃藥打卡',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      // 版面設計：上方 SingleChildScrollView 包住「資訊區」（headline + 藥單卡 +
      // 藥典圖片），下方用 Column + Padding 固定「主要動作區」（大圓按鈕 + 返回）。
      //
      // 為什麼這樣分？舊版用 `Column + Spacer`，當藥典圖片載入後內容超出螢幕
      // 高度，會觸發 RenderFlex overflow（畫面底部出現黃黑斜紋的「BOTTOM
      // OVERFLOWED BY xxx PIXELS」），長輩看不到打卡按鈕也滑不動。
      // 改成「scroll + fixed bottom」後：
      // - 上方資訊區可任意捲動，再多藥單細節都不會撐爆
      // - 下方主要動作（大圓按鈕、返回）永遠看得到，不會被內容推出畫面
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      headlineText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (slotLabel.isNotEmpty && !showLockedView)
                      Text(
                        '提醒時段：$slotLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loadingRx)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: _green),
                        ),
                      )
                    else if (rx != null)
                      MedicationIdentityCard(
                        record: rx,
                        slotTime: slotLabel.isNotEmpty ? slotLabel : null,
                      )
                    else
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            '找不到這張藥單的資料，\n請到「健康」分頁確認藥單是否仍存在。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    if (!_loadingRx) ...[
                      const SizedBox(height: 20),
                      DrugImageSection(
                        future: _drugImageFuture ??
                            Future<DrugImageLookup>.value(
                              const DrugImageNotFound(),
                            ),
                        onRetry: _retryDrugImageLookup,
                        heroTag: 'drug-image-${widget.prescriptionId}',
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // ----- 下方固定動作區 -----
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  if (_done)
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _celebrate,
                        curve: Curves.elasticOut,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 120,
                        color: _green,
                      ),
                    )
                  else if (showLockedView)
                    const _AlreadyLoggedBadge()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size =
                            (constraints.maxWidth * 0.72).clamp(180.0, 260.0);
                        // 三種「不可按」狀態：送出中／cooldown 中／（防呆）已完成。
                        // 視覺上灰色＋禁用 ripple；文字也跟著切換，讓長輩清楚知道
                        // 「為什麼按不下去」。
                        final bool busy = _submitting;
                        final bool locked = busy || _inCooldown;
                        final String label;
                        if (busy) {
                          label = '送出中…';
                        } else if (_inCooldown) {
                          label = '⏳ 請稍候\n再按一次';
                        } else {
                          label = '✅ 我剛剛吃過藥了';
                        }
                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Material(
                              color:
                                  locked ? Colors.grey.shade500 : _green,
                              elevation: locked ? 2 : 8,
                              shadowColor: Colors.black45,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: locked ? null : _submit,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: size > 230 ? 26 : 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(
                            color: Colors.black38, width: 2),
                      ),
                      child: const Text(
                        '返回首頁',
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
          ],
        ),
      ),
    );
  }
}

/// 「今日已打卡」靜態徽章（取代大圓打卡按鈕）。
///
/// 視覺上要看起來「完成、可離開」，與「剛剛打完卡」的 [Icons.check_circle]
/// 動畫做區隔；後者是慶祝、前者是日常狀態。
class _AlreadyLoggedBadge extends StatelessWidget {
  const _AlreadyLoggedBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.verified_rounded,
              size: 92,
              color: Color(0xFF2E7D32),
            ),
            SizedBox(height: 14),
            Text(
              '今天這個時段已完成',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                height: 1.3,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '辛苦了，繼續保持規律服藥喔！',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF33691E),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
