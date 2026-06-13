import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_bp/features/prescription/prescription_models.dart';

import 'ocr_service.dart';
import 'pii_redactor.dart';

/// 藥單「OCR + LLM 解讀」服務。
///
/// 雙階段架構：
///   1. **本地端 OCR**：用 [OcrService.extractRawText] 把藥袋照片用 ML Kit
///      在裝置端離線辨識成純文字（中文）。
///   2. **雲端結構化**：把純文字傳給 `process_prescription_vision`
///      Edge Function，由 Gemini 「文字模式」整理成
///      `{hospital, 領藥日, 服藥時段, 藥物 list...}`，回填到 `prescriptions` 列。
///
/// 為什麼從「整張照片丟 Vision」改成「先 OCR 再丟文字」？
/// - Vision API 的 quota 比較緊、503 過載常見（先前長輩會直接看到錯誤）
/// - 文字模式便宜很多、回應穩定，prompt 也更可控（不會被印刷雜訊影響）
/// - 不必上傳大張藥單到 Storage，省頻寬 + 保隱私（圖像不離開裝置）
class PrescriptionVisionService {
  PrescriptionVisionService({SupabaseClient? client, OcrService? ocrService})
      : _client = client ?? Supabase.instance.client,
        _ocrService = ocrService ?? OcrService();

  final SupabaseClient _client;
  final OcrService _ocrService;
  final ImagePicker _picker = ImagePicker();

  /// 釋放底層 ML Kit TextRecognizer；在 widget dispose 時呼叫。
  Future<void> dispose() => _ocrService.dispose();

  Future<PrescriptionResult?> processImage(ImageSource source) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw UnsupportedError('藥單辨識僅支援 Android 與 iOS 手機。');
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return null;

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('請先登入帳號');
    }

    // --- Step 1: 在裝置端 OCR 出純文字 ---
    // ML Kit 用 GPU 加速，多數中文藥袋約 0.5~1 秒即可拿到結果；完全離線。
    final String rawText;
    try {
      final rawOcr = await _ocrService.extractRawText(picked.path);
      // 在「文字離開裝置前」先去識別化：身分證、姓名、生日、電話、病歷號等 PII
      // 不會送到 Edge Function / Gemini，也不會在後續流程落地到 DB。
      // 醫院名、藥名、領藥日、服藥時段等解析所需欄位刻意保留。
      rawText = redactPrescriptionPii(rawOcr);
    } catch (e) {
      // ML Kit 在桌面 / Web 會丟 UnsupportedError；其他例外通常是檔案讀取失敗。
      throw StateError('辨識照片時出了點問題，請再試一次。\n（$e）');
    }

    if (rawText.trim().isEmpty) {
      throw StateError(
        '看不太清楚藥袋上的字，\n'
        '請把光線打亮一點、鏡頭靠近一些再拍。',
      );
    }

    final prescriptionId = const Uuid().v4();
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // --- Step 2: 開一筆 prescription row 占位（vision_status=processing） ---
    // Edge Function 完成後會把同一列 update 成 completed 並回填欄位；若失敗則 update 成 failed。
    await _client.from('prescriptions').insert({
      'id': prescriptionId,
      'user_id': uid,
      'medication_name': '（藥名請見藥袋或備註）',
      'pickup_date': _formatIsoDate(todayOnly),
      'take_medicine_times': <String>[],
      'vision_status': 'processing',
      'medications_detail': <dynamic>[],
      'status': 'active',
      'source': 'ocr',
    });

    // --- Step 3: 呼叫 Edge Function；Gemini 忙碌時自動重試，仍失敗則改本地 OCR 解析 ---
    try {
      return await _invokeVisionWithRetry(
        prescriptionId: prescriptionId,
        rawText: rawText,
        imagePath: picked.path,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[PrescriptionVision] 雲端解析失敗: $e');
      if (_isGeminiCapacityError(e)) {
        // Demo／尖峰時段：雲端 AI 配額滿仍可用本地規則解析，避免整條流程卡死。
        // 重點：沿用同一筆占位列 id（不刪除、不另開新列），確認時以 upsert
        // 寫回同一列，避免「刪除失敗 + 重新 insert」造成重複／幽靈藥單。
        // ignore: avoid_print
        print('[PrescriptionVision] Gemini 忙碌，改走本地 OCR 解析（沿用占位列 $prescriptionId）');
        final local = _ocrService.parseRawText(
          rawText,
          imagePath: picked.path,
        );
        return local.copyWith(
          prescriptionId: prescriptionId,
          isLocalFallback: true,
        );
      }
      // 非配額類錯誤：刪掉占位列避免殘留孤兒列，再把錯誤往上拋給 UI。
      await _deletePlaceholderRow(prescriptionId);
      rethrow;
    }
  }

  /// 呼叫 Edge Function，配額／過載時短暫重試一次。
  Future<PrescriptionResult> _invokeVisionWithRetry({
    required String prescriptionId,
    required String rawText,
    required String imagePath,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
      try {
        return await _invokeVisionOnce(
          prescriptionId: prescriptionId,
          rawText: rawText,
          imagePath: imagePath,
        );
      } catch (e) {
        lastError = e;
        if (!_isGeminiCapacityError(e)) rethrow;
      }
    }
    throw lastError!;
  }

  Future<PrescriptionResult> _invokeVisionOnce({
    required String prescriptionId,
    required String rawText,
    required String imagePath,
  }) async {
    FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'process_prescription_vision',
        body: {
          'prescription_id': prescriptionId,
          'raw_text': rawText,
        },
      );
    } on FunctionException catch (e) {
      throw _translateFunctionException(e);
    }

    final status = response.status;
    final payload = response.data;

    if (status != 200) {
      throw _translatePayloadError(status, payload);
    }

    if (payload is! Map) {
      throw StateError('辨識的回應格式怪怪的，請再試一次。');
    }

    final map = Map<String, dynamic>.from(payload);
    if (map['ok'] != true) {
      throw _translatePayloadError(status, map);
    }

    final data = Map<String, dynamic>.from(
      (map['data'] as Map?) ?? const {},
    );

    return _mapVisionData(
      data: data,
      prescriptionId: prescriptionId,
      imagePath: imagePath,
      rawText: rawText,
    );
  }

  /// Gemini 配額滿（429）或暫時過載（503）——可改走本地 OCR 或重試。
  bool _isGeminiCapacityError(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      String? code;
      if (details is Map) {
        code = details['code']?.toString();
      }
      return code == 'rate_limit' ||
          code == 'overload' ||
          e.status == 429 ||
          e.status == 503;
    }
    if (e is StateError) {
      final msg = e.message;
      return msg.contains('人太多') || msg.contains('太忙');
    }
    final lower = e.toString().toLowerCase();
    return lower.contains('429') ||
        lower.contains('503') ||
        lower.contains('rate_limit') ||
        lower.contains('overload') ||
        lower.contains('太忙碌');
  }

  /// 辨識失敗時清掉 [processImage] 寫下的 status='active' 占位列。
  ///
  /// best-effort：刪除本身再失敗（網路續斷）也只記 log，不覆蓋原始錯誤，
  /// 讓 UI 仍顯示「請再試一次」的友善訊息。下次重掃會建立新的 UUID 占位列，
  /// 殘留的那筆最壞情況也只是孤兒列，但正常情況都會被這裡清掉。
  Future<void> _deletePlaceholderRow(String prescriptionId) async {
    try {
      final deleted = await _client
          .from('prescriptions')
          .delete()
          .eq('id', prescriptionId)
          .select('id');
      if ((deleted as List).isEmpty) {
        await _client.from('prescriptions').update({
          'status': 'cancelled',
          'vision_status': VisionStatus.failed,
        }).eq('id', prescriptionId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[PrescriptionVision] 清除占位藥單列失敗 $prescriptionId: $e');
    }
  }

  /// 把 [FunctionException] 翻成長輩看得懂的 [StateError]。
  ///
  /// `details` 可能是：
  /// - Map ── 我們 Edge Function 自己回的 `{error, code}`
  /// - String ── 純文字錯誤訊息
  /// - 其他 ── fallback 走 toString
  StateError _translateFunctionException(FunctionException e) {
    final details = e.details;
    String? code;
    String? errMsg;
    if (details is Map) {
      code = details['code']?.toString();
      errMsg = (details['error'] ?? details['message'])?.toString();
    } else if (details is String) {
      errMsg = details;
    }
    return _buildFriendlyError(
      status: e.status,
      code: code,
      errMsg: errMsg ?? e.reasonPhrase ?? '辨識失敗',
    );
  }

  /// 從 Edge Function 回傳的 payload 萃取錯誤碼／訊息，並轉成 friendly `StateError`。
  StateError _translatePayloadError(int status, Object? payload) {
    String? code;
    String? errMsg;
    if (payload is Map) {
      code = payload['code']?.toString();
      errMsg = (payload['error'] ?? payload['message'])?.toString();
    }
    return _buildFriendlyError(
      status: status,
      code: code,
      errMsg: errMsg ?? '看圖辨識的時候出了點小狀況。',
    );
  }

  /// 根據 status / code / 錯誤訊息推測「該給長輩看哪句話」。
  ///
  /// 優先序：
  /// 1. `code == 'rate_limit'` 或 status 429 → 「太忙了，1 分鐘後再試」
  /// 2. `code == 'overload'`、status 503、或訊息含「Gemini」「overload」→
  ///    「AI 小幫手剛剛太忙，等 30 秒～1 分鐘再試」
  /// 3. 其他 → 含糊的「出了點小狀況，請再試一次」（不暴露技術細節給長輩）
  StateError _buildFriendlyError({
    required int status,
    String? code,
    required String errMsg,
  }) {
    final lower = errMsg.toLowerCase();
    final isRateLimit = code == 'rate_limit' ||
        status == 429 ||
        lower.contains('rate') ||
        lower.contains('429') ||
        errMsg.contains('太忙碌');
    if (isRateLimit) {
      return StateError('辨識的人太多啦，\n請等約 1 分鐘再按「再試一次」。');
    }

    final isOverload = code == 'overload' ||
        status == 503 ||
        lower.contains('overload') ||
        lower.contains('unavailable') ||
        lower.contains('503') ||
        lower.contains('gemini');
    if (isOverload) {
      return StateError(
        'AI 小幫手剛剛太忙，\n請休息 30 秒到 1 分鐘後再按「再試一次」。',
      );
    }

    return StateError('看圖辨識的時候出了點小狀況，\n請稍候再按「再試一次」。');
  }

  PrescriptionResult _mapVisionData({
    required Map<String, dynamic> data,
    required String prescriptionId,
    required String imagePath,
    required String rawText,
  }) {
    final hospitalName = data['hospitalName'] as String?;
    final pickupIso = data['pickupDateInferred'] as String?;
    final medicationDays = data['medicationDays'] as int?;
    final isInferred = data['isInferred'] as bool? ?? pickupIso != null;
    final times = _parseStringList(data['takeMedicineTimes']);
    final names = <String>[];
    final generics = <String>[];

    final meds = data['medications'];
    if (meds is List) {
      for (final m in meds) {
        if (m is Map) {
          final n = m['name']?.toString().trim();
          final generic = m['genericName']?.toString().trim();
          if (generic != null && generic.isNotEmpty) generics.add(generic);
          // 把學名（英文成分）併進顯示／查詢名，例如「雅脈 (Olmesartan)」，
          // 藥典是用學名建檔，這樣藥典圖片才比對得到。
          if (n != null && n.isNotEmpty) {
            if (generic != null &&
                generic.isNotEmpty &&
                !n.toLowerCase().contains(generic.toLowerCase())) {
              names.add('$n ($generic)');
            } else {
              names.add(n);
            }
          } else if (generic != null && generic.isNotEmpty) {
            names.add(generic);
          }
        }
      }
    }
    if (names.isEmpty) {
      final single = data['medicationName'] as String?;
      if (single != null && single.trim().isNotEmpty) {
        names.add(single.trim());
      }
    }

    final pillAppearance = data['pillAppearance'] as String?;

    String? pickupDisplay;
    if (pickupIso != null && pickupIso.isNotEmpty) {
      pickupDisplay = isInferred ? pickupIso : _rocDisplayFromIso(pickupIso);
    }

    return PrescriptionResult(
      prescriptionId: prescriptionId,
      // rawText 用「本地 ML Kit 真實 OCR 文字」而非 Gemini 回傳的 JSON——
      // 後者只是結構化欄位，沒有意義；前者才是「傳給志工幫忙」要附的素材。
      rawText: rawText,
      hospitalName: hospitalName?.trim().isNotEmpty == true
          ? hospitalName!.trim()
          : null,
      pickupDate: pickupDisplay,
      medicationDays: medicationDays,
      isInferred: isInferred,
      takeMedicineTimes: times,
      medicationNames: names,
      genericNames: generics,
      pillAppearance: pillAppearance?.trim().isNotEmpty == true
          ? pillAppearance!.trim()
          : null,
      imagePath: imagePath,
    );
  }

  List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String _rocDisplayFromIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final roc = d.year - 1911;
    return '$roc 年 ${d.month} 月 ${d.day} 日';
  }

  static String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
