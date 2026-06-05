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
    this.medicationNames = const <String>[],
    this.genericNames = const <String>[],
    this.pillAppearance,
    this.imagePath,
    this.prescriptionId,
  });

  /// 雲端 Vision 流程已寫入的 `prescriptions.id`（確認時勿重複 insert）。
  final String? prescriptionId;

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

  /// 藥丸外觀／形狀／顏色描述（例如「粉紅/圓形」）；辨識不到為 `null`。
  final String? pillAppearance;

  /// OCR 擷取到的藥品名稱（可能多種，已去重）。
  final List<String> medicationNames;

  /// 藥品學名／英文成分名（如 Olmesartan、Metformin），供藥典比對放寬召回用。
  /// 注意：學名為「弱詞」，只能放寬查詢，不能單獨成立比對（不同藥廠外觀不同）。
  final List<String> genericNames;

  /// 寫入 DB 用：多種藥以「、」串成一行。
  String? get combinedMedicationName =>
      medicationNames.isEmpty ? null : medicationNames.join('、');

  /// 顯示／畫圖用：外觀欄位或從藥名推斷。
  String get effectivePillAppearance {
    final p = pillAppearance?.trim();
    if (p != null && p.isNotEmpty) return p;
    return _inferPillHintFromNames(medicationNames);
  }

  static String _inferPillHintFromNames(List<String> names) {
    final text = names.join('');
    if (text.isEmpty) return '';
    final buf = StringBuffer();
    for (final c in ['粉紅', '紅', '白', '黃', '藍', '綠']) {
      if (text.contains(c)) buf.write(c);
    }
    for (final s in ['圓', '橢圓', '長', '膠囊', '錠']) {
      if (text.contains(s)) {
        if (buf.isNotEmpty) buf.write('/');
        buf.write(s);
      }
    }
    return buf.toString();
  }

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

  /// TextRecognizer 為 persistent field：ML Kit 在首次建立時需要載入中文模型，
  /// 重複使用同一個實例可省去後續掃描的初始化開銷（約 200~500ms）。
  final _recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  bool _recognizerClosed = false;

  /// 釋放底層 ML Kit 資源；widget dispose 時呼叫。
  Future<void> dispose() async {
    if (!_recognizerClosed) {
      _recognizerClosed = true;
      await _recognizer.close();
    }
  }

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

  /// 中文標籤「外觀：」後描述（僅在通過 [_isUsableAppearanceText] 時採用）。
  static final RegExp _pillAppearanceLabelRegExp = RegExp(
    r'(?:外觀|形狀|顏色|特徵)\s*[:：]\s*([^\n]+)',
  );

  /// 台灣醫院藥袋常見：「錠劑、長橢圓形、白色」同一行（優先於英文 Appearance）。
  static final RegExp _twTabletAppearanceRegExp = RegExp(
    r'(?:錠劑|膜衣錠|糖衣錠|膠囊|粒)'
    r'[、,，\s]*'
    r'((?:長)?橢圓形?|圓形?|長形)'
    r'[、,，\s]*'
    r'(白色?|粉紅色?|黃色?|紅色?|藍色?|綠色?|橘色?|橙色?)',
  );

  /// 「粉紅/圓形」「白色圓形錠」等常見寫法。
  static final RegExp _pillSlashRegExp = RegExp(
    r'(粉紅色?|紅色?|白色?|黃色?|藍色?|綠色?|橘色?|橙色?)\s*[\/／]\s*(圓形?|橢圓形?|長形?|膠囊|錠)',
  );

  static final RegExp _pillCompactRegExp = RegExp(
    r'(粉紅|白|黃|藍|綠|紅|橘|橙)(色)?(圓|橢圓|長)(形)?(錠|膠囊)?',
  );

  /// 藥品名稱標籤行。
  static final RegExp _drugLabelRegExp = RegExp(
    r'(?:藥\s*品\s*名\s*稱|藥\s*名|品\s*名)\s*[:：]?\s*([^\n]+)',
  );

  /// 藥袋商品名：(跌)【40mg】Olmetec 雅脈 (Olmesartan)
  static final RegExp _brandDrugLineRegExp = RegExp(
    r'[\(（][^)）]{1,12}[)）]?\s*'
    r'(?:【\s*\d+\s*mg\s*】)?\s*'
    r'[A-Za-z01OlI]{3,24}\s*'
    r'[\u4e00-\u9fff]{2,12}'
    r'(?:\s*\([A-Za-z][A-Za-z\s\-]+\))?',
    caseSensitive: false,
  );

  /// 英文副作用關鍵字（藥袋上常誤印在 Appearance 欄，需排除）。
  static final RegExp _sideEffectEnglishRegExp = RegExp(
    r'\b(?:dizz|headache|bronchi|diarrhea|hematur|hyperlip|nausea|vomit|'
    r'rash|pruritus|fatigue|cough|insomnia|may\s+occur|side\s+effect)\b',
    caseSensitive: false,
  );

  /// 含劑型關鍵字的藥品行（錠、膠囊、mg 等）。
  static final RegExp _drugLineRegExp = RegExp(
    r'^[\u4e00-\u9fffA-Za-z0-9\-\+\(\)（）·\s]{2,48}'
    r'(?:錠|膜衣錠|膠囊|粒|粉劑|注射液|軟膏|貼片)'
    r'(?:\s*\d+\s*(?:mg|毫克|mcg|公克|gm|g|ml|mL))?',
    caseSensitive: false,
  );

  /// 中文藥名 + 劑量（例：普拿疼 500mg）。
  static final RegExp _drugWithDoseRegExp = RegExp(
    r'^([\u4e00-\u9fff]{2,12})\s+\d+\s*(?:mg|毫克|mcg|公克|gm|g)\b',
    caseSensitive: false,
  );

  /// 根據來源（相機 / 相簿）取得照片並進行 OCR 辨識與後處理。
  ///
  /// [source] 決定是要開啟相機還是從相簿挑選照片。
  /// 若使用者取消取得照片，會回傳 `null`，方便上層保持在 Idle 狀態。
  ///
  /// 注意：production 用的「OCR + LLM」雙階段流程改走
  /// [PrescriptionVisionService.processImage]，會呼叫 [extractRawText] 拿純文字
  /// 再交給 Gemini 結構化。這個方法保留給離線測試與單元測試用。
  Future<PrescriptionResult?> processImage(ImageSource source) async {
    _ensureSupportedPlatform();

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      return null;
    }

    final rawText = await extractRawText(pickedFile.path);
    return _parsePrescription(
      rawText,
      now: DateTime.now(),
      imagePath: pickedFile.path,
    );
  }

  /// 純 ML Kit 文字辨識：只做「圖片 → 文字」，不做任何 regex 抽取。
  ///
  /// 給 [PrescriptionVisionService] 在雙階段流程裡呼叫——本地端先把藥單照片
  /// 變成純文字，再把純文字（不是圖片）丟給 Gemini 結構化解析。這樣可以：
  /// - 不必上傳大張照片到 Storage / Gemini API
  /// - 改走 Gemini 的「文字模式」配額，較不容易 503 過載
  /// - 把隱私敏感的圖像處理留在裝置端
  ///
  /// [imagePath] 必須是本機檔案路徑（[XFile.path] 或 [PickedFile.path]）。
  /// 在 Web / 桌面平台呼叫會拋 [UnsupportedError]（ML Kit 沒實作）。
  Future<String> extractRawText(String imagePath) async {
    _ensureSupportedPlatform();
    if (_recognizerClosed) {
      throw StateError('OcrService 已釋放，請重建實例。');
    }
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  /// 將原始 OCR 文字解析成 [PrescriptionResult]。對外公開以便撰寫單元測試
  /// （測試時可注入 [now] 凍結「今天」以驗證推算邏輯）。
  PrescriptionResult parseRawText(
    String rawText, {
    DateTime? now,
    String? imagePath,
  }) =>
      _parsePrescription(
        rawText,
        now: now ?? DateTime.now(),
        imagePath: imagePath,
      );

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
    final medicationNames = _extractMedicationNames(rawText);
    final pillAppearance = _extractPillAppearance(rawText, medicationNames);

    final directDate = _extractRocDate(rawText);
    if (directDate != null) {
      return PrescriptionResult(
        rawText: rawText,
        hospitalName: hospital,
        pickupDate: directDate,
        takeMedicineTimes: takeTimes,
        medicationNames: medicationNames,
        pillAppearance: pillAppearance,
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
        medicationNames: medicationNames,
        pillAppearance: pillAppearance,
        imagePath: imagePath,
      );
    }

    return PrescriptionResult(
      rawText: rawText,
      hospitalName: hospital,
      takeMedicineTimes: takeTimes,
      medicationNames: medicationNames,
      pillAppearance: pillAppearance,
      imagePath: imagePath,
    );
  }

  /// 從 OCR 擷取藥品名稱（最多 4 種）。
  List<String> _extractMedicationNames(String rawText) {
    final found = <String>[];
    final seen = <String>{};

    void addName(String raw) {
      final name = _normalizeDrugName(raw);
      if (name.isEmpty || seen.contains(name)) return;
      seen.add(name);
      found.add(name);
    }

    for (final m in _drugLabelRegExp.allMatches(rawText)) {
      final v = m.group(1)?.trim();
      if (v != null && v.length >= 2) addName(v);
    }

    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.length < 3) continue;
      if (_hospitalLineRegExp.hasMatch(line)) continue;
      if (_rocDateRegExp.hasMatch(line)) continue;
      if (line.contains('領藥') || (line.contains('處方') && line.length < 8)) {
        continue;
      }
      if (_isSideEffectLine(line) || line.contains('警語') || line.contains('副作用')) {
        continue;
      }

      final brand = _brandDrugLineRegExp.firstMatch(line);
      if (brand != null) {
        addName(brand.group(0)!);
        continue;
      }

      final doseMatch = _drugWithDoseRegExp.firstMatch(line);
      if (doseMatch != null) {
        addName(doseMatch.group(1)!);
        continue;
      }

      if (_drugLineRegExp.hasMatch(line)) {
        addName(line);
      }
    }

    if (found.length <= 4) return found;
    return found.sublist(0, 4);
  }

  /// 修正 OCR 常見誤字（如 01metec → Olmetec）。
  String _normalizeDrugName(String raw) {
    var s = _cleanDrugName(raw);
    if (s.isEmpty) return s;

    s = s.replaceAll(RegExp(r'\b01metec\b', caseSensitive: false), 'Olmetec');
    s = s.replaceAll(RegExp(r'\b0lmetec\b', caseSensitive: false), 'Olmetec');
    s = s.replaceAll(RegExp(r'\bO1metec\b'), 'Olmetec');

    // 去掉尾端劑量殘留與「共 N 顆」。
    s = s.replaceFirst(RegExp(r'\s*共\s*\d+\s*顆.*$'), '');
    s = s.replaceFirst(RegExp(r'\s+\d+\s*排\d+\s*顆.*$'), '');

    if (s.length > 48) s = '${s.substring(0, 48)}…';
    return s.trim();
  }

  String _cleanDrugName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  bool _isSideEffectLine(String line) =>
      _sideEffectEnglishRegExp.hasMatch(line) ||
      line.contains('可能發生') ||
      line.contains('Do not take');

  /// 外觀文字是否可用（排除英文副作用欄與 OCR 雜訊）。
  bool _isUsableAppearanceText(String text) {
    final t = text.trim();
    if (t.length < 2) return false;
    if (_isSideEffectLine(t)) return false;

    final cjkCount = RegExp(r'[\u4e00-\u9fff]').allMatches(t).length;
    final hasShapeColor = RegExp(
      r'白|粉紅|紅|黃|藍|綠|橘|橙|圓|橢圓|長|錠|膠囊',
    ).hasMatch(t);

    if (cjkCount == 0 && !hasShapeColor) return false;

    // 像「。体nd」這種幾乎沒有中文的碎片直接丟棄。
    if (cjkCount == 0 && t.length < 6) return false;
    if (RegExp(r'^[。．\s\.,;:!?\-a-zA-Z0-9]{1,10}$').hasMatch(t)) {
      return false;
    }

    return true;
  }

  /// 從單行文字組出「顏色/形狀」外觀描述。
  String? _appearanceFromShapeColor(String shape, String color) {
    final s = shape.trim();
    final c = color.trim();
    if (s.isEmpty && c.isEmpty) return null;
    if (s.isNotEmpty && c.isNotEmpty) return '$c/$s';
    return s.isNotEmpty ? s : c;
  }

  /// 從含「錠劑、長橢圓形、白色」的整行擷取外觀。
  String? _appearanceFromTabletLine(String line) {
    final m = _twTabletAppearanceRegExp.firstMatch(line);
    if (m != null) {
      return _appearanceFromShapeColor(m.group(1) ?? '', m.group(2) ?? '');
    }

    if (!line.contains('錠') && !line.contains('膠囊')) return null;

    String? shape;
    String? color;
    if (line.contains('長橢圓') || line.contains('长椭圆')) {
      shape = '長橢圓形';
    } else if (line.contains('橢圓')) {
      shape = '橢圓形';
    } else if (line.contains('圓形') || line.contains('圆形')) {
      shape = '圓形';
    } else if (line.contains('長形')) {
      shape = '長形';
    }

    for (final key in ['白色', '粉紅', '紅色', '紅', '黃色', '黃', '藍色', '藍', '綠色', '綠', '橘', '橙']) {
      if (line.contains(key)) {
        color = key.endsWith('色') ? key : '$key色';
        if (key == '紅' && line.contains('粉紅')) continue;
        break;
      }
    }

    return _appearanceFromShapeColor(shape ?? '', color ?? '');
  }

  /// 從 OCR 文字擷取藥丸外觀描述（台灣醫院藥袋優先）。
  String? _extractPillAppearance(String rawText, List<String> medicationNames) {
    // 1) 優先：含「錠劑、長橢圓形、白色」的中文描述行。
    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final fromTablet = _appearanceFromTabletLine(line);
      if (fromTablet != null && _isUsableAppearanceText(fromTablet)) {
        return fromTablet;
      }
    }

    // 2) 全文搜尋台灣藥袋句式。
    final tw = _twTabletAppearanceRegExp.firstMatch(rawText);
    if (tw != null) {
      final built = _appearanceFromShapeColor(tw.group(1) ?? '', tw.group(2) ?? '');
      if (built != null && _isUsableAppearanceText(built)) return built;
    }

    // 3) 中文「外觀：」標籤（排除英文副作用那一行）。
    for (final m in _pillAppearanceLabelRegExp.allMatches(rawText)) {
      final value = m.group(1)?.trim();
      if (value == null || value.isEmpty) continue;
      if (!_isUsableAppearanceText(value)) continue;
      return value.length > 80 ? '${value.substring(0, 80)}…' : value;
    }

    final slash = _pillSlashRegExp.firstMatch(rawText);
    if (slash != null) {
      final built = '${slash.group(1)}/${slash.group(2)}';
      if (_isUsableAppearanceText(built)) return built;
    }

    final compact = _pillCompactRegExp.firstMatch(rawText);
    if (compact != null) {
      final built = compact.group(0)?.trim();
      if (built != null && _isUsableAppearanceText(built)) return built;
    }

    final inferred = PrescriptionResult._inferPillHintFromNames(medicationNames);
    if (inferred.isNotEmpty && _isUsableAppearanceText(inferred)) {
      return inferred;
    }
    return null;
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
