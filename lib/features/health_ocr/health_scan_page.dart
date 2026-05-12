// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/notification_service.dart';
import '../../shared/widgets/mindu_loading_overlay.dart';
import '../prescription/prescription_provider.dart';
import '../profile/profile_provider.dart';
import '../volunteer/volunteer_task_provider.dart';
import 'ocr_service.dart';

/// 「藥單小幫手」掃描頁面（長輩友善大字體 UX）。
///
/// 整個頁面是一個明確的狀態機：
///
/// - [_ScanStatus.idle]    → 提供拍照 / 相簿兩個超大按鈕
/// - [_ScanStatus.loading] → 正在 OCR 辨識中
/// - [_ScanStatus.success] → 抓到民國日期：請使用者確認後設提醒
/// - [_ScanStatus.noDate]  → 抓不到日期：可能是一般藥單或拍不清楚
/// - [_ScanStatus.error]   → 辨識失敗（取消選圖、平台不支援、ML Kit 錯誤）
class HealthScanPage extends ConsumerStatefulWidget {
  const HealthScanPage({super.key});

  @override
  ConsumerState<HealthScanPage> createState() => _HealthScanPageState();
}

enum _ScanStatus { idle, loading, success, noDate, error }

class _HealthScanPageState extends ConsumerState<HealthScanPage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _accentBlue = Color(0xFF1565C0);
  static const Color _warningOrange = Color(0xFFE65100);
  static const Color _alertRed = Color(0xFFC62828);
  static const Color _backgroundCream = Color(0xFFFFF8E1);

  final OcrService _ocrService = OcrService();

  _ScanStatus _status = _ScanStatus.idle;
  PrescriptionResult? _result;
  String? _errorMessage;

  /// 「傳給志工幫忙」進行中：顯示遮罩並擋住其他互動，避免重複送單。
  bool _isSubmittingToVolunteer = false;

  Future<void> _handleScan(ImageSource source) async {
    if (_status == _ScanStatus.loading) return;

    setState(() {
      _status = _ScanStatus.loading;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _ocrService.processImage(source);
      if (!mounted) return;

      if (result == null) {
        // 使用者取消選圖：靜悄悄回到 Idle，不顯示錯誤打擾。
        setState(() => _status = _ScanStatus.idle);
        return;
      }

      if (result.rawText.trim().isEmpty) {
        setState(() {
          _status = _ScanStatus.error;
          _errorMessage = '這張照片好像沒有看到字耶，\n可以幫我把藥單放大、再拍清楚一點嗎？';
        });
        return;
      }

      setState(() {
        _result = result;
        _status = result.hasDate ? _ScanStatus.success : _ScanStatus.noDate;
      });
    } catch (e) {
      print('[HealthScan] OCR error: $e');
      if (!mounted) return;
      setState(() {
        _status = _ScanStatus.error;
        _errorMessage = e is UnsupportedError
            ? (e.message?.toString() ?? '此裝置不支援 OCR 辨識。')
            : '辨識的時候出了點小狀況：\n$e';
      });
    }
  }

  void _resetToIdle() {
    setState(() {
      _status = _ScanStatus.idle;
      _result = null;
      _errorMessage = null;
    });
  }

  void _backToHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// Success：寫入 `prescriptions` + 依藥單 UUID 排本機通知（與其他藥單並存）。
  ///
  /// [pickupDate]：已含「基準日校準」後的領藥日；[baselineDate] 僅在推算情境有意義。
  Future<void> _confirmAndScheduleReminders({
    required DateTime pickupDate,
    DateTime? baselineDate,
  }) async {
    final result = _result;
    if (result == null) {
      _backToHome();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: _warningOrange,
          duration: Duration(seconds: 5),
          content: Text(
            '請先登入帳號，才能記錄藥單喔。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final prescriptionId = const Uuid().v4();
    final pickupDay =
        DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
    final baselineDay = baselineDate != null
        ? DateTime(baselineDate.year, baselineDate.month, baselineDate.day)
        : null;

    try {
      final preview = result.rawText.length > 800
          ? '${result.rawText.substring(0, 800)}…'
          : result.rawText;
      await ref.read(prescriptionRepositoryProvider).insertOcrPrescription(
            id: prescriptionId,
            userId: uid,
            hospitalName: result.hospitalName,
            pickupDate: pickupDay,
            takeMedicineTimes: result.takeMedicineTimes,
            medicationDays: result.medicationDays,
            baselineDate: baselineDay,
            rawNotes: preview,
          );
    } catch (e) {
      print('[HealthScan] insert prescription error: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: _alertRed,
          duration: const Duration(seconds: 8),
          content: Text(
            '藥單紀錄寫入失敗（請確認 Supabase 已建立 prescriptions 表）：\n$e',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ),
      );
      return;
    }

    NotificationScheduleResult scheduleResult;
    try {
      scheduleResult =
          await NotificationService.instance.schedulePrescriptionReminders(
        prescriptionId: prescriptionId,
        takeMedicineTimes: result.takeMedicineTimes,
        pickupDate: pickupDay,
        hospitalName: result.hospitalName,
      );
    } catch (e) {
      print('[HealthScan] schedule reminder error: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: _warningOrange,
          duration: const Duration(seconds: 5),
          content: Text(
            '提醒設定失敗了：$e\n您可以稍後在「我的藥單」調整。',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      ref.invalidate(activePrescriptionsProvider);
      _backToHome();
      return;
    }

    if (!mounted) return;

    if (!scheduleResult.granted) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: _warningOrange,
          duration: Duration(seconds: 6),
          content: Text(
            '⚠️ 還沒打開「通知」權限喔，\n請到手機設定 → 應用程式 → 明德 e 達人 → 通知，把它打開才會收到提醒。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
          ),
        ),
      );
      ref.invalidate(activePrescriptionsProvider);
      _backToHome();
      return;
    }

    final feedback = _buildScheduleFeedback(scheduleResult);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: _primaryGreen,
        duration: const Duration(seconds: 5),
        content: Text(
          feedback,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
        ),
      ),
    );
    ref.invalidate(activePrescriptionsProvider);
    _backToHome();
  }

  /// 依排程結果組合一段對長輩友善的中文訊息。
  String _buildScheduleFeedback(NotificationScheduleResult result) {
    if (!result.hasAnyScheduled) {
      return '已記下這張藥單，但這次沒有可以設定的提醒。';
    }
    final parts = <String>[];
    if (result.medicationCount > 0) {
      parts.add('每天 ${result.medicationCount} 個吃藥時段');
    }
    if (result.pickupScheduled) {
      parts.add('下次回診領藥日');
    }
    return '🔔 已幫您設好提醒（${parts.join('、')}），到時間手機會叮咚通知您！';
  }

  /// NoDate 狀態的「這是慢箋（傳給志工幫忙）」按鈕：
  /// 1. 跳確認 dialog，避免長輩誤觸。
  /// 2. 從 [profileProvider] 抓姓名 / 手機作為聯絡 snapshot。
  /// 3. 透過 [volunteerTaskSubmitterProvider]：
  ///    a. 把 [PrescriptionResult.imagePath] 指到的原始藥單照片上傳到
  ///       Supabase Storage（`volunteer-task-photos`，私人 bucket）；
  ///    b. 拿到 object path 後，連同 OCR 文字一起 insert 到 `volunteer_tasks`，
  ///       讓志工同時看到原圖與 OCR 文字（OCR 不準時志工可比對原圖）。
  /// 4. 顯示成功 / 失敗 SnackBar 後回首頁。
  Future<void> _sendToVolunteer() async {
    final result = _result;
    if (result == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '要請社區志工幫忙嗎？',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '我會把這張藥單的「原始照片」傳給社區志工，\n志工會主動打電話跟您確認下次拿藥的時間。',
          style: TextStyle(fontSize: 20, height: 1.5),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              '先不要',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _alertRed,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              '好，幫我傳',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isSubmittingToVolunteer = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 取得目前長輩的個人資料當聯絡 snapshot：
      // 為什麼要 snapshot？日後長輩改了姓名 / 手機，這筆任務仍會保留送出當下
      // 的版本，志工不會聯絡到對不上的人。
      final profile = ref.read(profileProvider).value;

      await ref.read(volunteerTaskSubmitterProvider).submit(
            rawOcrText: result.rawText,
            hospitalName: result.hospitalName,
            elderName: profile?.name,
            elderPhone: profile?.phone,
            // 把原始藥單照片一起送上 Storage，志工可在儀表板查看原圖。
            imagePath: result.imagePath,
            takeMedicineTimes: result.takeMedicineTimes,
          );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: _primaryGreen,
          duration: Duration(seconds: 5),
          content: Text(
            '✅ 已把藥單照片傳給社區志工，志工會主動跟您聯絡喔！',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      _backToHome();
    } catch (e) {
      print('[HealthScan] submit volunteer task error: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: _alertRed,
          duration: const Duration(seconds: 6),
          content: Text(
            '❌ 傳給志工失敗了：$e\n您可以稍後再試一次。',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingToVolunteer = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundCream,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          '藥單小幫手',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        toolbarHeight: 72,
      ),
      body: SafeArea(
        child: MinduLoadingOverlay(
          isLoading: _isSubmittingToVolunteer,
          message: '正在上傳藥單照片給志工，請稍候…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: _buildBodyForStatus(),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyForStatus() {
    switch (_status) {
      case _ScanStatus.idle:
        return _IdleView(
          onCamera: () => _handleScan(ImageSource.camera),
          onGallery: () => _handleScan(ImageSource.gallery),
        );
      case _ScanStatus.loading:
        return const _LoadingView();
      case _ScanStatus.success:
        return _SuccessView(
          result: _result!,
          onConfirm: _confirmAndScheduleReminders,
        );
      case _ScanStatus.noDate:
        return _NoDateView(
          result: _result!,
          onGeneralCase: _backToHome,
          onChronicCase: _sendToVolunteer,
          onRetake: _resetToIdle,
        );
      case _ScanStatus.error:
        return _ErrorView(
          message: _errorMessage ?? '發生未知錯誤',
          onRetry: _resetToIdle,
        );
    }
  }
}

// ============================================================================
//  狀態 1：Idle（準備拍照）
// ============================================================================

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '藥單小幫手',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _HealthScanPageState._primaryGreen,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '請選擇要怎麼把藥單給我看看 👇',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _BigActionButton(
          label: '📷 拍照掃描',
          color: _HealthScanPageState._primaryGreen,
          onPressed: onCamera,
        ),
        const SizedBox(height: 16),
        _BigActionButton(
          label: '🖼️ 從相簿挑選',
          color: _HealthScanPageState._accentBlue,
          onPressed: onGallery,
        ),
        const SizedBox(height: 28),
        _TipCard(
          icon: '💡',
          text: '小提醒：請把藥單放在光線明亮的桌面上拍喔！',
        ),
      ],
    );
  }
}

// ============================================================================
//  狀態 2：Loading（辨識中）
// ============================================================================

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: const [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              strokeWidth: 8,
              color: _HealthScanPageState._primaryGreen,
            ),
          ),
          SizedBox(height: 32),
          Text(
            '👀 小幫手正在努力\n看您的藥單，',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _HealthScanPageState._primaryGreen,
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '請稍等一下下喔...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  狀態 3：Success（成功抓到日期）
// ============================================================================

class _SuccessView extends StatefulWidget {
  const _SuccessView({
    required this.result,
    required this.onConfirm,
  });

  final PrescriptionResult result;

  /// [pickupDate]：領藥日（已換算成 DateTime，時間視為當日 00:00 語意）。
  /// [baselineDate]：開始吃藥／領藥基準日（推算模式下記錄用）。
  final Future<void> Function({
    required DateTime pickupDate,
    DateTime? baselineDate,
  }) onConfirm;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> {
  /// 「是否為今天剛拿到的藥」— `true` 時基準日鎖定為今日。
  bool _todayMedicine = true;

  /// 推算模式下：從哪一天開始算給藥天數（純日期）。
  late DateTime _baselineStart;

  bool _confirmBusy = false;

  @override
  void initState() {
    super.initState();
    _baselineStart = _startOfDay(DateTime.now());
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 依「基準日 + 給藥天數」或 OCR 直接結果取得領藥日（全日語意）。
  DateTime? get _effectivePickup {
    final r = widget.result;
    if (r.isInferred && r.medicationDays != null) {
      final base = _startOfDay(_baselineStart);
      return base.add(Duration(days: r.medicationDays!));
    }
    return r.pickupDateTime;
  }

  String _formatChineseDay(DateTime d) =>
      '${d.year} 年 ${d.month} 月 ${d.day} 日';

  String _formatInferredFromIso(String iso) {
    try {
      final parsed = DateTime.parse(iso);
      return _formatChineseDay(parsed);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _pickOtherBaselineDay() async {
    final initial = _baselineStart;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: '您開始吃這包藥的日期',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked != null && mounted) {
      setState(() => _baselineStart = _startOfDay(picked));
    }
  }

  void _setTodayMedicineYes() {
    setState(() {
      _todayMedicine = true;
      _baselineStart = _startOfDay(DateTime.now());
    });
  }

  void _setTodayMedicineNo() {
    setState(() {
      _todayMedicine = false;
    });
  }

  void _nudgeBaselineByDays(int deltaDays) {
    final today = _startOfDay(DateTime.now());
    setState(() {
      _baselineStart = _startOfDay(today.add(Duration(days: deltaDays)));
    });
  }

  Future<void> _onTapFinish() async {
    final pickup = _effectivePickup;
    if (pickup == null) return;

    setState(() => _confirmBusy = true);
    try {
      await widget.onConfirm(
        pickupDate: pickup,
        baselineDate:
            widget.result.isInferred && widget.result.medicationDays != null
                ? _startOfDay(_baselineStart)
                : null,
      );
    } finally {
      if (mounted) setState(() => _confirmBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final inferred = r.isInferred && r.medicationDays != null;
    final dateLabel =
        inferred ? '下次拿藥的時間（依基準日重新推算）' : '下次拿藥的時間';

    final effective = _effectivePickup;
    final dateText = effective != null
        ? _formatChineseDay(effective)
        : (inferred ? _formatInferredFromIso(r.pickupDate!) : '民國 ${r.pickupDate!}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '✅ 記下來了！\n太棒了！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _HealthScanPageState._primaryGreen,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.hospitalName != null) ...[
                  const _InfoLabel(icon: '🏥', label: '看診的醫院'),
                  const SizedBox(height: 8),
                  Text(
                    r.hospitalName!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: 32, thickness: 1),
                ],
                _InfoLabel(icon: '📅', label: dateLabel),
                const SizedBox(height: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _HealthScanPageState._alertRed,
                    height: 1.4,
                  ),
                ),
                if (inferred && r.medicationDays != null) ...[
                  const SizedBox(height: 16),
                  _InferredHint(days: r.medicationDays!),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE65100).withValues(alpha: 0.45),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '請問這是您今天剛拿到的藥嗎？',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                            color: Color(0xFFBF360C),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _HugeChoiceButton(
                                label: '✅ 是',
                                color: _HealthScanPageState._primaryGreen,
                                selected: _todayMedicine,
                                onTap: _setTodayMedicineYes,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HugeChoiceButton(
                                label: '否',
                                color: _HealthScanPageState._accentBlue,
                                selected: !_todayMedicine,
                                onTap: _setTodayMedicineNo,
                              ),
                            ),
                          ],
                        ),
                        if (!_todayMedicine) ...[
                          const SizedBox(height: 20),
                          const Text(
                            '請選開始吃藥的那一天（或小幫手才知道怎麼推算）：',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _QuickDayChip(
                                label: '前天',
                                onTap: () => _nudgeBaselineByDays(-2),
                              ),
                              _QuickDayChip(
                                label: '昨天',
                                onTap: () => _nudgeBaselineByDays(-1),
                              ),
                              _QuickDayChip(
                                label: '今天',
                                onTap: () => _nudgeBaselineByDays(0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 64,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _pickOtherBaselineDay,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                side: const BorderSide(
                                  color: Colors.black38,
                                  width: 2,
                                ),
                              ),
                              child: const Text(
                                '📆 選其他日期…',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '目前基準日：${_formatChineseDay(_baselineStart)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (r.hasTakeMedicineTimes) ...[
          const SizedBox(height: 20),
          _TakeMedicineTimesCard(times: r.takeMedicineTimes),
        ],
        const SizedBox(height: 20),
        _TipCard(
          icon: '🔔',
          text: '時間快到時，手機會叮咚提醒您喔！',
          backgroundColor: const Color(0xFFE8F5E9),
          textColor: _HealthScanPageState._primaryGreen,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 96,
          child: ElevatedButton(
            onPressed: (_confirmBusy || effective == null) ? null : _onTapFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: _HealthScanPageState._primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 3,
            ),
            child: _confirmBusy
                ? const SizedBox(
                    height: 36,
                    width: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '完成，回首頁',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _HugeChoiceButton extends StatelessWidget {
  const _HugeChoiceButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(16),
      elevation: selected ? 4 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDayChip extends StatelessWidget {
  const _QuickDayChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
        ),
      ),
    );
  }
}

/// 推算日期的溫馨提示卡：說明這個日期是系統算出來的、不是藥單直接寫的。
class _InferredHint extends StatelessWidget {
  const _InferredHint({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE65100).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '小幫手看到這包藥有 $days 天份，\n已經幫您自動推算下次拿藥日囉！',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 每日吃藥時間 Card：顯示「⏰ 每日吃藥時間」+ 各時段的圖示 + HH:mm。
///
/// 採 [Wrap] 自動換行，避免時段多時擠在一起；每個時段用獨立的藥色膠囊包起來，
/// 即使在小螢幕（5~6 吋）長輩手機上也不會擠到變形。
class _TakeMedicineTimesCard extends StatelessWidget {
  const _TakeMedicineTimesCard({required this.times});

  final List<String> times;

  /// 依時段對應到生活化的圖示。
  ///
  /// - 早上：`08:00` / `09:00` → ☀️
  /// - 中午：`11:30` / `13:00` → 🕛
  /// - 傍晚：`18:00` / `19:00` → 🌙
  /// - 睡前：`22:00` → 🛏️
  /// - 其他不在表中：fallback ⏰
  static String _emojiForTime(String time) {
    switch (time) {
      case '08:00':
      case '09:00':
        return '☀️';
      case '11:30':
      case '13:00':
        return '🕛';
      case '18:00':
      case '19:00':
        return '🌙';
      case '22:00':
        return '🛏️';
      default:
        return '⏰';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _HealthScanPageState._accentBlue.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('⏰', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Text(
                '每日吃藥時間',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _HealthScanPageState._accentBlue,
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final time in times)
                _TimeChip(emoji: _emojiForTime(time), time: time),
            ],
          ),
        ],
      ),
    );
  }
}

/// 單一時段膠囊：圖示 + 24 小時制時間，字體 22pt 高對比。
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.emoji, required this.time});

  final String emoji;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _HealthScanPageState._accentBlue.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              height: 1,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  狀態 4：NoDate（抓不到日期 → 容錯機制）
// ============================================================================

class _NoDateView extends StatelessWidget {
  const _NoDateView({
    required this.result,
    required this.onGeneralCase,
    required this.onChronicCase,
    required this.onRetake,
  });

  final PrescriptionResult result;
  final VoidCallback onGeneralCase;
  final VoidCallback onChronicCase;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '👀 小幫手看完囉！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _HealthScanPageState._warningOrange,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: Colors.white,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '這張藥單上好像沒有寫下次拿藥的時間。\n\n'
              '如果您看的是一般感冒，\n只要把藥乖乖吃完就好囉！\n\n'
              '但如果您拍的是慢性病藥單，\n可以幫我再拍一次，\n或者傳給志工幫您確認喔！',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _BigActionButton(
          label: '這是一般藥單\n回首頁',
          color: _HealthScanPageState._primaryGreen,
          onPressed: onGeneralCase,
        ),
        const SizedBox(height: 16),
        _BigActionButton(
          label: '這是慢箋\n傳給志工幫忙',
          color: _HealthScanPageState._alertRed,
          onPressed: onChronicCase,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.refresh, size: 28),
          label: const Text(
            '再拍一次試試看',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _HealthScanPageState._accentBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  狀態 5：Error（辨識失敗）
// ============================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '😣 哎呀，沒看清楚',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _HealthScanPageState._warningOrange,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: const Color(0xFFFFF3E0),
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBF360C),
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _BigActionButton(
          label: '🔄 再試一次',
          color: _HealthScanPageState._primaryGreen,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

// ============================================================================
//  共用元件
// ============================================================================

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 96,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 3,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  final String icon;
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (textColor ?? const Color(0xFFE65100)).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: textColor ?? const Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
