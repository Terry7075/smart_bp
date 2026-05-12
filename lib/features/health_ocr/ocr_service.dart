import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// 處方籤 OCR 解析結果。
///
/// 由 [OcrService.processImage] 回傳，內含原始 OCR 文字以及從中萃取出的
/// 醫療院所名稱與下次領藥日期，方便上層 UI 依不同狀態顯示。
///
/// `pickupDate` 有兩種來源：
/// 1. **明確擷取**（[isInferred] = `false`）：藥單上直接寫了民國日期，
///    例如「115 年 5 月 10 日」，此時格式為「`XXX 年 XX 月 XX 日`」。
/// 2. **推算結果**（[isInferred] = `true`）：藥單只寫天數（例如「共 28 天」），
///    系統用 `DateTime.now() + days` 推算出來，格式為「`yyyy-MM-dd`」。
class PrescriptionResult {
  const PrescriptionResult({
    required this.rawText,
    this.hospitalName,
    this.pickupDate,
    this.medicationDays,
    this.isInferred = false,
    this.takeMedicineTimes = const <String>[],
    this.imagePath,
  });

  /// ML Kit OCR 辨識出的整段原始文字（保留原始換行）。
  final String rawText;

  /// 使用者剛剛挑 / 拍的「原始照片」在裝置上的暫存檔案路徑。
  ///
  /// - 由 [OcrService.processImage] 帶回，僅在當前 App session 內有效。
  /// - 用途：「傳給志工幫忙」時把這張原圖上傳到 Supabase Storage，
  ///   讓志工真的看到藥單的樣子，而不是只有 OCR 文字。
  /// - 沒走 [OcrService.processImage]（例如測試直接呼叫 [OcrService.parseRawText]）
  ///   時會是 `null`，呼叫端要自行處理。
  final String? imagePath;

  /// 解析到的醫院 / 診所名稱；若辨識不到則為 `null`。
  final String? hospitalName;

  /// 解析到的下次領藥日期字串。
  /// - [isInferred] = `false` 時為民國格式「XXX 年 XX 月 XX 日」。
  /// - [isInferred] = `true`  時為西元格式「yyyy-MM-dd」。
  /// - 若辨識不到則為 `null`，通常代表這張不是慢性病連續處方箋。
  final String? pickupDate;

  /// 從藥單擷取到的給藥天數（僅在 [isInferred] 為 true 時有值）。
  final int? medicationDays;

  /// 是否為「由天數 + 今日推算」而得；用於 UI 在 Success 畫面顯示溫馨提示。
  final bool isInferred;

  /// 解析後的每日服藥時段（24 小時制 `HH:mm` 字串），已排序去重。
  ///
  /// 範例：`['09:00', '13:00', '19:00']` 表示一日三餐飯後服用。
  /// 若無法解析（藥單沒寫或 OCR 不清）則為空陣列。
  final List<String> takeMedicineTimes;

  /// 是否成功抓到日期：用來判斷 UI 要走 Success 或 NoDate 狀態。
  bool get hasDate => pickupDate != null;

  /// 是否抓到服藥時段（給 UI 判斷要不要顯示吃藥時間 Card）。
  bool get hasTakeMedicineTimes => takeMedicineTimes.isNotEmpty;

  /// 將 [pickupDate] 字串轉成 [DateTime]（西元年），給通知排程使用。
  ///
  /// 兩種輸入格式都會被正確處理：
  /// - 推算結果（[isInferred] = `true`）：`yyyy-MM-dd` → 直接交給 [DateTime.tryParse]。
  /// - 直接擷取（[isInferred] = `false`）：`XXX 年 XX 月 XX 日`（民國年）→ 民國年 + 1911。
  ///
  /// 任一步驟失敗（沒有日期、格式異常）都回傳 `null`，由呼叫端決定要不要排提醒。
  DateTime? get pickupDateTime {
    final value = pickupDate;
    if (value == null) return null;

    if (isInferred) {
      return DateTime.tryParse(value);
    }

    final match =
        RegExp(r'(\d{2,3})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日').firstMatch(value);
    if (match == null) return null;

    final rocYear = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '');
    if (rocYear == null || month == null || day == null) return null;

    try {
      return DateTime(rocYear + 1911, month, day);
    } catch (_) {
      return null;
    }
  }
}

/// 健康處方籤 / 藥袋 OCR 辨識服務
///
/// 使用 Google ML Kit 在裝置端（邊緣運算）辨識照片中的繁體中文文字，
/// 不需要將照片上傳雲端，兼顧隱私與速度，並進一步抽出醫院與民國日期。
///
/// 注意：底層 ML Kit SDK 僅支援 Android 與 iOS，於 Web / Windows / macOS
/// 桌面版會直接拋出 [UnsupportedError] 讓上層呈現友善提示。
class OcrService {
  OcrService();

  final ImagePicker _picker = ImagePicker();

  /// 台灣民國日期：兩到三位民國年 + 年 + 月 + 日，中間允許空白。
  ///
  /// 範例可命中：`114 年 11 月 20 日`、`114年11月20日`、`99 年 1 月 5 日`。
  static final RegExp _rocDateRegExp = RegExp(
    r'(\d{2,3})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日',
  );

  /// 醫院 / 診所行：抓含「醫院」或「診所」二字的整行文字。
  static final RegExp _hospitalLineRegExp = RegExp(r'^.*(醫院|診所).*$');

  /// 給藥天數：可命中「天數：28 天」、「共 30 天」、「14天」、「服用 7 天」等。
  ///
  /// 採非貪婪前綴 + 數字 + 「天」，捕獲群組為純整數的天數字串。
  static final RegExp _medicationDaysRegExp = RegExp(
    r'(?:天數|共)?\s*[:：]?\s*(\d+)\s*天',
  );

  // ---------------------------------------------------------------------------
  // 服藥時段相關 Regex
  //
  // 注意比對順序：必須由「最具體」到「最一般」，否則「三餐」會優先吃掉
  // 「三餐飯前」/「三餐飯後」的判斷。實際取用時序依 [_extractTakeMedicineTimes]。
  // ---------------------------------------------------------------------------

  /// 三餐飯前
  static final RegExp _threeMealsBeforeRegExp = RegExp(r'三\s*餐\s*飯\s*前');

  /// 早晚飯前
  static final RegExp _morningEveningBeforeRegExp =
      RegExp(r'早\s*晚\s*飯\s*前');

  /// 三餐飯後
  static final RegExp _threeMealsAfterRegExp = RegExp(r'三\s*餐\s*飯\s*後');

  /// 早晚飯後
  static final RegExp _morningEveningAfterRegExp =
      RegExp(r'早\s*晚\s*飯\s*後');

  /// 三餐（未指明飯前 / 飯後，預設視為飯後）
  static final RegExp _threeMealsRegExp = RegExp(r'三\s*餐');

  /// 早晚（未指明飯前 / 飯後，預設視為飯後）
  static final RegExp _morningEveningRegExp = RegExp(r'早\s*晚');

  /// 睡前（疊加用，不論其他規則皆會額外加 22:00）
  static final RegExp _bedtimeRegExp = RegExp(r'睡\s*前');

  /// 一天 N 次（例如「一天 3 次」、「一日 2 次」），fallback 用。
  static final RegExp _frequencyRegExp =
      RegExp(r'一\s*[天日]\s*(\d+)\s*次');

  /// 根據來源（相機 / 相簿）取得照片並進行 OCR 辨識與後處理。
  ///
  /// [source] 決定是要開啟相機還是從相簿挑選照片。
  /// 若使用者取消取得照片，會回傳 `null`，方便上層保持在 Idle 狀態。
  Future<PrescriptionResult?> processImage(ImageSource source) async {
    _ensureSupportedPlatform();

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return null;
    }

    final TextRecognizer textRecognizer = TextRecognizer(
      script: TextRecognitionScript.chinese,
    );

    try {
      final InputImage inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return _parsePrescription(
        recognizedText.text,
        now: DateTime.now(),
        imagePath: pickedFile.path,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// 將原始 OCR 文字解析成 [PrescriptionResult]。對外公開以便撰寫單元測試
  /// （測試時可注入 [now] 凍結「今天」以驗證推算邏輯）。
  PrescriptionResult parseRawText(String rawText, {DateTime? now}) =>
      _parsePrescription(rawText, now: now ?? DateTime.now());

  /// 雙層擷取邏輯：
  /// 1. 第一優先：直接抓藥單上明確的民國日期。
  /// 2. 第二優先：抓給藥天數（例如「共 28 天」），用 `now + days` 推算西元日期。
  ///
  /// 兩者皆失敗才回傳沒有日期的結果，由 UI 走 NoDate 容錯流程。
  /// 服藥時段（[PrescriptionResult.takeMedicineTimes]）在三種狀態下都會嘗試解析。
  ///
  /// [imagePath] 為原始照片的本機檔案路徑，會原封不動帶到結果裡，供
  /// 「傳給志工幫忙」時上傳到 Storage 用；測試呼叫可不帶。
  PrescriptionResult _parsePrescription(
    String rawText, {
    required DateTime now,
    String? imagePath,
  }) {
    final hospital = _extractHospital(rawText);
    final takeTimes = _extractTakeMedicineTimes(rawText);

    final directDate = _extractRocDate(rawText);
    if (directDate != null) {
      return PrescriptionResult(
        rawText: rawText,
        hospitalName: hospital,
        pickupDate: directDate,
        takeMedicineTimes: takeTimes,
        imagePath: imagePath,
      );
    }

    final days = _extractMedicationDays(rawText);
    if (days != null) {
      final target = now.add(Duration(days: days));
      return PrescriptionResult(
        rawText: rawText,
        hospitalName: hospital,
        pickupDate: _formatIsoDate(target),
        medicationDays: days,
        isInferred: true,
        takeMedicineTimes: takeTimes,
        imagePath: imagePath,
      );
    }

    return PrescriptionResult(
      rawText: rawText,
      hospitalName: hospital,
      takeMedicineTimes: takeTimes,
      imagePath: imagePath,
    );
  }

  /// 從整段文字找出第一個含「醫院」或「診所」的行，回傳整行（已 trim）。
  ///
  /// 若 OCR 把同一行拆成多片段，這裡仍以行為單位回傳，避免誤抓到旁邊的醫師或科別。
  String? _extractHospital(String rawText) {
    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_hospitalLineRegExp.hasMatch(line)) {
        return line;
      }
    }
    return null;
  }

  /// 從整段文字找出第一個民國日期，並重新格式化為「XXX 年 XX 月 XX 日」。
  String? _extractRocDate(String rawText) {
    final match = _rocDateRegExp.firstMatch(rawText);
    if (match == null) return null;

    final year = match.group(1);
    final month = match.group(2);
    final day = match.group(3);
    if (year == null || month == null || day == null) return null;

    return '$year 年 $month 月 $day 日';
  }

  /// 從整段文字找出第一筆給藥天數（整數）。
  ///
  /// 為了避免誤抓到「服用 1 天」之類過短的療程，做了下列保護：
  /// - 至少 1 天、最多 365 天，超出範圍視為雜訊。
  int? _extractMedicationDays(String rawText) {
    final match = _medicationDaysRegExp.firstMatch(rawText);
    if (match == null) return null;

    final raw = match.group(1);
    if (raw == null) return null;

    final days = int.tryParse(raw);
    if (days == null) return null;
    if (days <= 0 || days > 365) return null;

    return days;
  }

  /// 把 [DateTime] 格式化為 `yyyy-MM-dd`（純文字，不依賴 `intl`）。
  String _formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 解析服藥時段，回傳 24 小時制 `HH:mm` 字串清單（已排序去重）。
  ///
  /// 比對優先序（由具體到一般）：
  /// 1. **飯前系列** — 三餐飯前：`08:00 / 11:30 / 18:00`；早晚飯前：`08:00 / 18:00`。
  /// 2. **飯後 / 預設系列** — 三餐飯後或單寫「三餐」：`09:00 / 13:00 / 19:00`；
  ///    早晚飯後或單寫「早晚」：`09:00 / 19:00`。
  /// 3. **次數 fallback** — 若上述都沒命中、但抓到「一天 N 次」：
  ///    1 次 → `08:00`；2 次 → `09:00 / 19:00`；
  ///    3 次 → `09:00 / 13:00 / 19:00`；4 次 → `09:00 / 13:00 / 19:00 / 22:00`。
  /// 4. **睡前** — 任何狀況下若文字含「睡前」皆額外加上 `22:00`（疊加，不互斥）。
  List<String> _extractTakeMedicineTimes(String rawText) {
    final times = <String>{};
    var matchedMealBased = false;

    // ---- Step 1 / 2：飯前 → 飯後 / 一般三餐早晚（互斥；最早命中為準）。
    if (_threeMealsBeforeRegExp.hasMatch(rawText)) {
      times.addAll(const ['08:00', '11:30', '18:00']);
      matchedMealBased = true;
    } else if (_morningEveningBeforeRegExp.hasMatch(rawText)) {
      times.addAll(const ['08:00', '18:00']);
      matchedMealBased = true;
    } else if (_threeMealsAfterRegExp.hasMatch(rawText) ||
        _threeMealsRegExp.hasMatch(rawText)) {
      times.addAll(const ['09:00', '13:00', '19:00']);
      matchedMealBased = true;
    } else if (_morningEveningAfterRegExp.hasMatch(rawText) ||
        _morningEveningRegExp.hasMatch(rawText)) {
      times.addAll(const ['09:00', '19:00']);
      matchedMealBased = true;
    }

    // ---- Step 3：若三餐 / 早晚都沒命中，用「一天 N 次」做 fallback。
    if (!matchedMealBased) {
      final freqMatch = _frequencyRegExp.firstMatch(rawText);
      final count = int.tryParse(freqMatch?.group(1) ?? '');
      switch (count) {
        case 1:
          times.add('08:00');
        case 2:
          times.addAll(const ['09:00', '19:00']);
        case 3:
          times.addAll(const ['09:00', '13:00', '19:00']);
        case 4:
          times.addAll(const ['09:00', '13:00', '19:00', '22:00']);
      }
    }

    // ---- Step 4：睡前疊加（與上面任何規則皆相容）。
    if (_bedtimeRegExp.hasMatch(rawText)) {
      times.add('22:00');
    }

    final sorted = times.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }

  /// ML Kit 僅支援 Android / iOS，其他平台直接丟出中文錯誤，
  /// 避免出現 MissingPluginException 這種對使用者沒意義的訊息。
  void _ensureSupportedPlatform() {
    if (kIsWeb) {
      throw UnsupportedError(
        '目前使用網頁版瀏覽器無法進行 OCR 辨識，請改用 Android 手機或 iPhone 開啟 App。',
      );
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError(
        '此裝置不支援 OCR 辨識，請改用 Android 手機或 iPhone 開啟 App。',
      );
    }
  }
}
