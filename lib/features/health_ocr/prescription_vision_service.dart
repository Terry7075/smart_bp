import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'ocr_service.dart';

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

  Future<PrescriptionResult?> processImage(ImageSource source) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw UnsupportedError('藥單辨識僅支援 Android 與 iOS 手機。');
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1280,
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
      rawText = await _ocrService.extractRawText(picked.path);
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

    // --- Step 3: 呼叫 Edge Function，傳「純文字」而非圖片 ---
    // `supabase_flutter@2.x` 對非 2xx 回應會直接 throw `FunctionException`，
    // 503（Gemini 過載）必須在這裡接住，否則整串技術字串會跑到長輩 UI。
    //
    // 重要：占位列已經以 status='active' 寫進 DB。一旦本段任何環節失敗
    // （Gemini 429/503、網路斷線、回應格式異常…），都必須把這筆占位列刪掉，
    // 否則它會以「（藥名請見藥袋或備註）」永久留在長輩的「使用中藥單」清單裡
    //（activePrescriptionsProvider 只濾 status='active'，不看 vision_status）。
    try {
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
        // 某些 supabase_flutter 版本對 4xx/5xx 不丟 exception，仍要翻譯。
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
        imagePath: picked.path,
        rawText: rawText,
      );
    } catch (_) {
      await _deletePlaceholderRow(prescriptionId);
      rethrow;
    }
  }

  /// 辨識失敗時清掉 [processImage] 寫下的 status='active' 占位列。
  ///
  /// best-effort：刪除本身再失敗（網路續斷）也只記 log，不覆蓋原始錯誤，
  /// 讓 UI 仍顯示「請再試一次」的友善訊息。下次重掃會建立新的 UUID 占位列，
  /// 殘留的那筆最壞情況也只是孤兒列，但正常情況都會被這裡清掉。
  Future<void> _deletePlaceholderRow(String prescriptionId) async {
    try {
      await _client.from('prescriptions').delete().eq('id', prescriptionId);
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

    final meds = data['medications'];
    if (meds is List) {
      for (final m in meds) {
        if (m is Map) {
          final n = m['name']?.toString().trim();
          if (n != null && n.isNotEmpty) names.add(n);
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
