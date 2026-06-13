/// 藥袋／處方箋 OCR 原文的個資（PII）去識別化工具。
///
/// 為什麼需要：藥單掃描雖然「圖片留在裝置端、只把純文字送雲端」，但 OCR 原文
/// 本身仍可能含病患姓名、身分證字號、出生日期、電話、病歷號等個資。這些文字會
/// 1. 送到 `process_prescription_vision` Edge Function → Google Gemini，
/// 2. 在「傳給志工」流程寫進 `volunteer_tasks`（永久落地、志工可讀）。
///
/// 因此在「文字離開裝置／落地前」先在 client 端做一次去識別化，PII 就不會流到
/// 第三方或資料庫。
///
/// 設計原則：
/// 1. 「精準遮罩」而非「整段刪」——避免把醫院名、藥名、領藥日、服藥時段也洗掉，
///    那會直接降低 Gemini 解析正確率。
/// 2. 高信心格式（身分證號、電話）用 pattern，全文皆可安全替換。
/// 3. 姓名／生日／病歷號因格式自由，用「關鍵字標籤 + 取值」的 label-based 遮罩，
///    且只動「該標籤後面那一段」，不碰其他行。
/// 4. 保留佔位符（如 `[身分證]`），讓 LLM 仍看得懂版面結構。
library;

/// 將藥袋／處方箋 OCR 原文中的個資去識別化。
///
/// 回傳遮罩後的文字；輸入為空字串時原樣回傳。
String redactPrescriptionPii(String raw) {
  if (raw.isEmpty) return raw;
  var text = raw;

  // --- 1. 身分證字號 / 居留證號（容忍 OCR 夾空白，如「A 1 2345 6789」）---
  // 規則：1 個英文字母 + (1|2) + 8 碼數字；命中後再做台灣身分證檢核碼驗證，
  // 避免把藥品批號、條碼之類的英數字串誤判成身分證。
  final nationalId = RegExp(r'[A-Za-z]\s?[12]\s?(?:\d\s?){8}');
  text = text.replaceAllMapped(nationalId, (m) {
    final compact = m[0]!.replaceAll(RegExp(r'\s'), '');
    return _isLikelyTwId(compact) ? '[身分證]' : m[0]!;
  });

  // --- 2. 手機 / 市話 ---
  text = text.replaceAll(
    RegExp(r'09\d{2}[-\s]?\d{3}[-\s]?\d{3}'),
    '[電話]',
  );
  text = text.replaceAll(
    RegExp(r'0\d{1,2}[-\s]?\d{6,8}'),
    '[電話]',
  );

  // --- 3. label-based：姓名 / 出生 / 病歷號 / 健保卡號（只洗標籤後那段）---
  // 注意：刻意「不」匹配「領藥」「調劑」「處方」等含日期但要保留的標籤。
  text = _redactAfterLabel(
    text,
    labels: const ['姓名', '病患', '患者', '病人'],
    placeholder: '[姓名]',
    valuePattern: r'[\u4e00-\u9fffA-Za-z·]{2,4}',
  );
  text = _redactAfterLabel(
    text,
    labels: const ['出生', '生日', 'Birth', 'DOB'],
    placeholder: '[生日]',
    valuePattern: r'[0-9一二三四五六七八九〇年月日民國/\-.\s]{4,20}',
  );
  text = _redactAfterLabel(
    text,
    labels: const ['病歷號碼', '病歷號', '病歷', 'Chart'],
    placeholder: '[病歷號]',
    valuePattern: r'[A-Za-z0-9\-]{4,20}',
  );
  text = _redactAfterLabel(
    text,
    labels: const ['健保卡號', '卡號'],
    placeholder: '[健保卡號]',
    valuePattern: r'[A-Za-z0-9\-]{6,20}',
  );

  return text;
}

/// 把「標籤 + 分隔符 + 值」中的值換成佔位符；只動值，保留標籤本身。
///
/// [labels] 會被當作正則的替代群組（請避免含正則特殊字元）；同義詞請由長到短排序，
/// 例如「病歷號碼」應排在「病歷」之前，否則「病歷」會先吃掉前綴造成殘留。
String _redactAfterLabel(
  String text, {
  required List<String> labels,
  required String placeholder,
  required String valuePattern,
}) {
  for (final label in labels) {
    final re = RegExp('($label)\\s*[:：]?\\s*(?:$valuePattern)');
    text = text.replaceAllMapped(re, (m) => '${m[1]}：$placeholder');
  }
  return text;
}

/// 台灣身分證檢核碼驗證，用來降低誤判（例如藥品批號被當成身分證）。
///
/// 演算法：首字母轉兩位數 → 十位 × 1 + 個位 × 9，後續 8 碼依序乘 8..1，
/// 最後加上檢查碼，總和需為 10 的倍數。
bool _isLikelyTwId(String id) {
  if (!RegExp(r'^[A-Za-z][12]\d{8}$').hasMatch(id)) return false;
  const letterMap = {
    'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15, 'G': 16, 'H': 17,
    'I': 34, 'J': 18, 'K': 19, 'L': 20, 'M': 21, 'N': 22, 'O': 35, 'P': 23,
    'Q': 24, 'R': 25, 'S': 26, 'T': 27, 'U': 28, 'V': 29, 'W': 32, 'X': 30,
    'Y': 31, 'Z': 33,
  };
  final n = letterMap[id[0].toUpperCase()];
  if (n == null) return false;

  var sum = n ~/ 10 + (n % 10) * 9;
  for (var i = 1; i <= 8; i++) {
    sum += int.parse(id[i]) * (9 - i);
  }
  sum += int.parse(id[9]);
  return sum % 10 == 0;
}
