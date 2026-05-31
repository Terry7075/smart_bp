// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/notification_service.dart';
import '../../shared/widgets/mindu_loading_overlay.dart';
import '../medication/drug_dictionary_service.dart';
import '../medication/widgets/drug_image_section.dart';
import '../medication/widgets/medication_identity_card.dart';
import '../prescription/prescription_models.dart';
import '../prescription/prescription_provider.dart';
import '../profile/profile_provider.dart';
import '../volunteer/volunteer_task_provider.dart';
import 'ocr_service.dart';
import 'prescription_vision_service.dart';

/// 「藥單小幫手」掃描頁面（長輩友善大字體 UX）。
///
/// 整個頁面是一個明確的狀態機：
///
/// - [_ScanStatus.idle]    → 提供拍照 / 相簿兩個超大按鈕
/// - [_ScanStatus.loading] → 正在 AI 看圖辨識中
/// - [_ScanStatus.success] → 抓到民國日期：請使用者確認後設提醒
/// - [_ScanStatus.noDate]  → 抓不到日期：可能是一般藥單或拍不清楚
/// - [_ScanStatus.error]   → 辨識失敗（取消選圖、平台不支援、雲端 Vision 錯誤）
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

  final PrescriptionVisionService _visionService = PrescriptionVisionService();

  _ScanStatus _status = _ScanStatus.idle;
  PrescriptionResult? _result;
  String? _errorMessage;

  /// 「傳給志工幫忙」進行中：顯示遮罩並擋住其他互動，避免重複送單。
  bool _isSubmittingToVolunteer = false;

  /// OCR 確認頁要顯示的藥典圖片查詢 Future。
  ///
  /// 進入 success 狀態時，依 OCR 抓到的藥名 candidates 同步打藥典，
  /// 讓長輩在確認服藥時段之前就看到「藥典裡這顆藥的真實照片」，提早發現
  /// Vision 把藥名認錯（例如把 Acetaminophen 認成 Amlodipine）的情況。
  Future<DrugImageLookup>? _ocrDrugImageFuture;

  Future<void> _handleScan(ImageSource source) async {
    if (_status == _ScanStatus.loading) return;

    setState(() {
      _status = _ScanStatus.loading;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _visionService.processImage(source);
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
        _ocrDrugImageFuture = _buildDrugImageFutureForOcr(result);
      });
    } catch (e) {
      print('[HealthScan] Vision error: $e');
      if (!mounted) return;
      setState(() {
        _status = _ScanStatus.error;
        _errorMessage = _visionErrorMessage(e);
      });
    }
  }

  /// 把可能來自 OCR / Vision 流程的任意例外，轉成「長輩看得懂的一句話」。
  ///
  /// `PrescriptionVisionService._buildFriendlyError` 已經把絕大多數情況包成
  /// `StateError` 帶友善訊息，這裡的 fallback 主要負責處理：
  /// - `UnsupportedError`（裝置不支援、Web/Desktop）
  /// - 沒走 service（例如測試呼叫）卻直接拋 `FunctionException`／純文字錯誤
  ///   的情境，仍然要避免把「FunctionException(status: 500, details: ...)」
  ///   這種技術字串直接秀給長輩。
  String _visionErrorMessage(Object e) {
    if (e is UnsupportedError) {
      return e.message?.toString() ?? '此裝置不支援藥單看圖辨識。';
    }
    if (e is StateError) {
      return e.message;
    }
    final s = e.toString();
    final lower = s.toLowerCase();

    if (s.contains('429') ||
        lower.contains('rate_limit') ||
        lower.contains('rate limit') ||
        s.contains('太忙碌') ||
        lower.contains('too many requests')) {
      return '辨識的人太多啦，\n請等約 1 分鐘再按「再試一次」。';
    }

    if (s.contains('503') ||
        lower.contains('overload') ||
        lower.contains('gemini') ||
        lower.contains('unavailable') ||
        lower.contains('internal server error')) {
      return 'AI 小幫手剛剛太忙，\n請休息 30 秒到 1 分鐘後再按「再試一次」。';
    }

    // 其他不明狀況：絕對不要把例外 toString 原樣 echo 出去（會看到
    // `FunctionException(status: 500, ...)` 這類嚇人字串）。
    return '看圖辨識的時候出了點小狀況，\n請稍候再按「再試一次」。';
  }

  void _resetToIdle() {
    setState(() {
      _status = _ScanStatus.idle;
      _result = null;
      _errorMessage = null;
      _ocrDrugImageFuture = null;
    });
  }

  /// 從 OCR 結果 build 藥典查詢 Future。
  /// `combinedMedicationName` 以「、」串接多藥，`buildDrugLookupCandidates`
  /// 再切回 candidates 餵給 service。
  Future<DrugImageLookup> _buildDrugImageFutureForOcr(
    PrescriptionResult result,
  ) {
    final candidates = buildDrugLookupCandidates(
      medicationName: result.combinedMedicationName,
    );
    if (candidates.isEmpty) {
      return Future<DrugImageLookup>.value(const DrugImageNotFound());
    }
    return ref
        .read(drugDictionaryServiceProvider)
        .fetchDrugImageForCandidates(candidates);
  }

  /// 「重新查詢藥典」按鈕：重新建一個 Future 觸發 [DrugImageSection] 重新 build。
  void _retryOcrDrugImageLookup() {
    final result = _result;
    if (result == null) return;
    setState(() {
      _ocrDrugImageFuture = _buildDrugImageFutureForOcr(result);
    });
  }

  void _backToHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// Success：寫入 `prescriptions` + 依藥單 UUID 排每日吃藥本機通知。
  ///
  /// [takeMedicineTimes] 由 [_SuccessView] 傳入「使用者在確認頁編輯過的版本」，
  /// 而非 OCR 原始結果——這是 Vision 解析錯誤時最後的補救機會。
  Future<void> _confirmAndScheduleReminders(
    List<String> takeMedicineTimes,
  ) async {
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

    final prescriptionId = result.prescriptionId ?? const Uuid().v4();

    if (result.prescriptionId == null) {
      final pickupDay = _pickupDayForDb(result);
      final baselineDay = result.isInferred && result.medicationDays != null
          ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          : null;

      try {
        final preview = result.rawText.length > 800
            ? '${result.rawText.substring(0, 800)}…'
            : result.rawText;
        await ref.read(prescriptionRepositoryProvider).insertOcrPrescription(
              id: prescriptionId,
              userId: uid,
              hospitalName: result.hospitalName,
              medicationName: result.combinedMedicationName,
              pickupDate: pickupDay,
              takeMedicineTimes: takeMedicineTimes,
              medicationDays: result.medicationDays,
              baselineDate: baselineDay,
              pillAppearance: result.effectivePillAppearance.isNotEmpty
                  ? result.effectivePillAppearance
                  : result.pillAppearance,
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
    } else {
      // Vision 流程：占位列已由 Edge Function 寫入「AI 解析的時段」。
      // 使用者若在確認頁改過時段，這裡必須回寫，否則本機通知會用編輯後的
      // 時間、但健康卡 / 打卡頁仍顯示 AI 原本的時段，兩邊對不上。
      try {
        await ref.read(prescriptionRepositoryProvider).updateTakeMedicineTimes(
              prescriptionId: prescriptionId,
              takeMedicineTimes: takeMedicineTimes,
            );
      } catch (e) {
        // 回寫失敗不阻斷後續排程；最壞情況只是顯示時段與通知時間有落差。
        print('[HealthScan] update take_medicine_times error: $e');
      }
    }

    NotificationScheduleResult scheduleResult;
    try {
      scheduleResult =
          await NotificationService.instance.schedulePrescriptionReminders(
        prescriptionId: prescriptionId,
        takeMedicineTimes: takeMedicineTimes,
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
      await _showNotificationPermissionDialog();
      if (!mounted) return;
      ref.invalidate(activePrescriptionsProvider);
      _backToHome();
      return;
    }

    final feedback = scheduleResult.hasAnyScheduled
        ? '✅ 設定完成！系統會每天按時提醒您吃藥喔！'
        : '已記下這張藥單，但這次沒有可以設定的吃藥提醒。';
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

  /// 通知權限被拒：用對話框（不會自動消失）清楚引導長輩到設定打開。
  Future<void> _showNotificationPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text(
          '⚠️ 還沒打開「通知」權限',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '藥單已經幫您記下來了，\n'
          '但因為通知還沒打開，暫時不會叮咚提醒您吃藥。\n\n'
          '請到手機的：\n'
          '設定 → 應用程式 → 明德 e 達人 → 通知\n'
          '把通知打開，就會準時提醒囉！',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primaryGreen),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                '我知道了',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 僅供雲端／志工端物流使用；長輩 UI 不再顯示領藥日。
  DateTime _pickupDayForDb(PrescriptionResult result) {
    final direct = result.pickupDateTime;
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }
    if (result.isInferred && result.medicationDays != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return today.add(Duration(days: result.medicationDays!));
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
            pillAppearance: result.effectivePillAppearance.isNotEmpty
                ? result.effectivePillAppearance
                : result.pillAppearance,
            medicationName: result.combinedMedicationName,
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
          drugImageFuture: _ocrDrugImageFuture,
          onConfirm: _confirmAndScheduleReminders,
          onRetake: _resetToIdle,
          onSendToVolunteer: _sendToVolunteer,
          onRetryDrugImage: _retryOcrDrugImageLookup,
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
            '👀 AI 小幫手正在努力\n看您的藥單，',
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
    required this.drugImageFuture,
    required this.onConfirm,
    required this.onRetake,
    required this.onSendToVolunteer,
    required this.onRetryDrugImage,
  });

  final PrescriptionResult result;

  /// 由 parent 預先打好的藥典圖片查詢 Future。`null` 代表沒有要查
  /// （目前不會發生，但保留 nullable 給未來「OCR 沒抓到任何藥名」的情境）。
  final Future<DrugImageLookup>? drugImageFuture;

  /// 確認按鈕的 callback，會帶回**使用者編輯後**的服藥時段。
  /// OCR 解析時段錯誤時（最常見的錯誤類型），長輩可在這頁直接更正，
  /// 不必整張藥單重拍或丟給志工。
  final Future<void> Function(List<String> takeMedicineTimes) onConfirm;
  final VoidCallback onRetake;
  final Future<void> Function() onSendToVolunteer;

  /// 「重新查詢藥典」按鈕的 callback，連到 parent 的 lookup 重打邏輯。
  final VoidCallback onRetryDrugImage;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> {
  bool _confirmBusy = false;

  /// 使用者編輯後的服藥時段（local copy）。
  /// 進頁面時用 OCR 結果初始化，之後 [_editTime] / [_addTime] / [_removeTime]
  /// 都只動這個列表，按下「資料都對」才送回 parent。
  late List<String> _takeMedicineTimes;

  @override
  void initState() {
    super.initState();
    _takeMedicineTimes = List<String>.from(widget.result.takeMedicineTimes);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _editTime(int idx) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(_takeMedicineTimes[idx]),
      helpText: '修改服藥時間',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked == null) return;
    setState(() {
      _takeMedicineTimes[idx] = _formatTime(picked);
      _takeMedicineTimes = _dedupAndSort(_takeMedicineTimes);
    });
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: '新增服藥時間',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked == null) return;
    setState(() {
      _takeMedicineTimes = _dedupAndSort([
        ..._takeMedicineTimes,
        _formatTime(picked),
      ]);
    });
  }

  void _removeTime(int idx) {
    setState(() => _takeMedicineTimes.removeAt(idx));
  }

  /// 去重 + 排序，避免使用者重複新增同一個時段（會讓 schedule 浪費通知槽位）。
  static List<String> _dedupAndSort(List<String> raw) {
    final set = <String>{};
    for (final t in raw) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty) set.add(trimmed);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _onTapFinish() async {
    if (_takeMedicineTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _HealthScanPageState._warningOrange,
          duration: Duration(seconds: 4),
          content: Text(
            '至少要保留一個服藥時段，才能設定提醒喔。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }
    setState(() => _confirmBusy = true);
    try {
      await widget.onConfirm(List<String>.unmodifiable(_takeMedicineTimes));
    } finally {
      if (mounted) setState(() => _confirmBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '👀 請確認以下資料是否正確',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _HealthScanPageState._primaryGreen,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '系統會依下列資料每天提醒您吃藥。\n服藥時段「輕觸」可以修改、按「－」刪除；\n如果整張藥單都不對，請按「重拍」或「請志工幫忙」。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        if (r.hospitalName != null) ...[
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                ],
              ),
            ),
          ),
        ],
        if (r.medicationNames.isNotEmpty ||
            r.effectivePillAppearance.isNotEmpty) ...[
          const SizedBox(height: 20),
          MedicationIdentityCard(
            record: PrescriptionRecord(
              id: 'preview',
              userId: '',
              medicationName: r.combinedMedicationName,
              pillAppearance: r.pillAppearance ?? r.effectivePillAppearance,
              status: 'active',
              source: 'ocr',
              createdAt: DateTime.now(),
            ),
            compact: true,
          ),
        ],
        if (widget.drugImageFuture != null) ...[
          const SizedBox(height: 20),
          DrugImageSection(
            future: widget.drugImageFuture!,
            onRetry: widget.onRetryDrugImage,
            heroTag: 'ocr-drug-image-${r.combinedMedicationName ?? r.rawText.hashCode}',
          ),
        ],
        const SizedBox(height: 20),
        _EditableTimesCard(
          times: _takeMedicineTimes,
          onEdit: _editTime,
          onAdd: _addTime,
          onRemove: _removeTime,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 96,
          child: ElevatedButton(
            onPressed: _confirmBusy ? null : _onTapFinish,
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
                    '✅ 資料都對，幫我設定提醒',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 72,
                child: OutlinedButton.icon(
                  onPressed: _confirmBusy ? null : widget.onRetake,
                  icon: const Icon(Icons.refresh, size: 24),
                  label: const Text(
                    '🔄 重新拍',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _HealthScanPageState._primaryGreen,
                    side: const BorderSide(
                      color: _HealthScanPageState._primaryGreen,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 72,
                child: OutlinedButton.icon(
                  onPressed: _confirmBusy
                      ? null
                      : () => widget.onSendToVolunteer(),
                  icon: const Icon(Icons.support_agent, size: 24),
                  label: const Text(
                    '🙋 請志工幫忙',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _HealthScanPageState._accentBlue,
                    side: const BorderSide(
                      color: _HealthScanPageState._accentBlue,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 可編輯版的「每日吃藥時間」卡片：時段 chip 可輕觸修改、按 ❌ 刪除，
/// 並提供「+ 新增時段」按鈕。Vision 解析錯誤時，長輩可直接在此修正而不需重拍。
///
/// 視覺維持與舊版 `_TakeMedicineTimesCard` 一致：白底圓角、藍色 emoji 配色，
/// 只是 Wrap 內每個 chip 多了一個 ❌ 圓鈕，並在最下方加上一條「+ 新增時段」row。
class _EditableTimesCard extends StatelessWidget {
  const _EditableTimesCard({
    required this.times,
    required this.onEdit,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> times;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function() onAdd;
  final void Function(int index) onRemove;

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
              Expanded(
                child: Text(
                  '每日吃藥時間',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _HealthScanPageState._accentBlue,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '輕觸時間可以修改；按右上 ❌ 刪除這個時段。',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (times.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '目前沒有設定時段，請按下方「＋ 新增時段」。',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBF360C),
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int i = 0; i < times.length; i++)
                  _EditableTimeChip(
                    emoji: _emojiForTime(times[i]),
                    time: times[i],
                    onTap: () => onEdit(i),
                    onRemove: () => onRemove(i),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline, size: 24),
              label: const Text(
                '＋ 新增時段',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _HealthScanPageState._accentBlue,
                side: const BorderSide(
                  color: _HealthScanPageState._accentBlue,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 單一可編輯時段：chip 本身 tap → 改時間；右上小圓鈕 → 刪除。
///
/// `Stack` + `Positioned` 把 ❌ 紅鈕「擠」到 chip 右上角外側，避免擋到時間
/// 文字，也讓刪除目標夠大（直徑 28），長輩好按。
class _EditableTimeChip extends StatelessWidget {
  const _EditableTimeChip({
    required this.emoji,
    required this.time,
    required this.onTap,
    required this.onRemove,
  });

  final String emoji;
  final String time;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: const Color(0xFFE3F2FD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _HealthScanPageState._accentBlue.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: const Color(0xFFC62828),
            shape: const CircleBorder(),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 依時段對應到生活化的圖示。
///
/// - 早上：`08:00` / `09:00` → ☀️
/// - 中午：`11:30` / `13:00` → 🕛
/// - 傍晚：`18:00` / `19:00` → 🌙
/// - 睡前：`22:00` → 🛏️
/// - 其他不在表中：fallback ⏰
String _emojiForTime(String time) {
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
  const _TipCard({required this.icon, required this.text});

  static const Color _bg = Color(0xFFFFF3E0);
  static const Color _fg = Color(0xFFBF360C);

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fg.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: _fg,
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
