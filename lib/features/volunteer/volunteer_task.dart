/// 志工任務狀態（對應 Supabase `volunteer_tasks.status` 欄位）。
///
/// DB 端用 [dbValue] 字串、UI 端用 [label] 中文顯示，請統一透過此 enum，
/// 避免拼字 / 翻譯散落各處。
///
/// 完整流程：
/// `pending` → 志工接手 → `inProgress` → 志工填表「確認並回傳」 → `active`
/// （長輩端首頁就會收到 Realtime 通知 + 自動排提醒）。
/// `done` 保留作為更後期的「結案」狀態，不必經過。
enum VolunteerTaskStatus {
  /// 長輩剛送出、還沒志工接手（=「pending_verification」）。
  pending('pending', '待處理'),

  /// 志工已認領、處理中（電聯中、查詢藥單細節中…）。
  inProgress('in_progress', '處理中'),

  /// 志工已填表回傳、長輩端可看到完整藥單與設好的鬧鐘。
  active('active', '已確認'),

  /// 已協助確認多日後人工結案（保留用，UI 端不必經過）。
  done('done', '已完成'),

  /// 長輩取消，或內部判定無法處理。
  cancelled('cancelled', '已取消');

  const VolunteerTaskStatus(this.dbValue, this.label);

  /// Supabase 端的字串值。
  final String dbValue;

  /// UI 顯示用的中文標籤。
  final String label;

  /// 從 DB 字串反查；找不到一律 fallback [pending]，避免 UI 崩潰。
  static VolunteerTaskStatus fromDb(String? value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    return pending;
  }
}

/// 「長輩送出 → 志工協助」的單筆任務。
///
/// 對應 Supabase `volunteer_tasks` 資料表，欄位設計目標：
/// - 即使長輩之後改了個人資料，這筆任務的 `elderName / elderPhone` 仍是
///   送出當下的 snapshot，避免志工聯絡到對不上的資訊。
/// - `rawOcrText` 是 OCR 原文，志工可以直接看到完整藥單內容做判斷，
///   不必依賴系統解析的醫院 / 日期。
/// - `photoPath` 是原始藥單照片在 Supabase Storage（私人 bucket
///   `volunteer-task-photos`）裡的 object path；志工端透過 signed URL 即時下載
///   顯示。長輩看不清楚的 OCR 文字，志工可以直接看原圖判讀。
class VolunteerTask {
  const VolunteerTask({
    required this.id,
    required this.elderId,
    required this.elderName,
    this.elderPhone,
    required this.rawOcrText,
    this.hospitalName,
    required this.status,
    required this.createdAt,
    this.claimedBy,
    this.claimedAt,
    this.notes,
    this.photoPath,
    this.pickupDate,
    this.takeMedicineTimes = const <String>[],
  });

  final String id;
  final String elderId;
  final String elderName;
  final String? elderPhone;
  final String rawOcrText;
  final String? hospitalName;
  final VolunteerTaskStatus status;
  final DateTime createdAt;
  final String? claimedBy;
  final DateTime? claimedAt;
  final String? notes;

  /// 原始藥單照片在 Storage bucket `volunteer-task-photos` 內的 object path，
  /// 例如 `{elder_uid}/1700000000_1234.jpg`。沒上傳照片時為 `null`。
  final String? photoPath;

  /// 志工填寫的「下次領藥日」（純日期，沒有時分秒）。
  ///
  /// `pending` / `inProgress` 階段為 `null`；`active` 之後一定有值。
  final DateTime? pickupDate;

  /// 志工勾選的每日服藥時段，例如 `['08:00', '13:00', '19:00', '22:00']`。
  ///
  /// `pending` / `inProgress` 階段為空；`active` 之後就是長輩鬧鐘要排的時段。
  final List<String> takeMedicineTimes;

  /// 這張任務有沒有附原始藥單照片。
  bool get hasPhoto => (photoPath ?? '').isNotEmpty;

  /// 若是處理中或已完成，是不是「我」這個志工負責的。
  bool isClaimedBy(String volunteerId) => claimedBy == volunteerId;

  /// 是否仍在開放認領中（待處理）。
  bool get isOpen => status == VolunteerTaskStatus.pending;

  /// 從 Supabase row 反序列化。
  factory VolunteerTask.fromMap(Map<String, dynamic> map) {
    return VolunteerTask(
      id: map['id'] as String,
      elderId: map['elder_id'] as String,
      elderName: (map['elder_name'] as String?) ?? '長輩',
      elderPhone: map['elder_phone'] as String?,
      rawOcrText: (map['raw_ocr_text'] as String?) ?? '',
      hospitalName: map['hospital_name'] as String?,
      status: VolunteerTaskStatus.fromDb(map['status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      claimedBy: map['claimed_by'] as String?,
      claimedAt: map['claimed_at'] != null
          ? DateTime.parse(map['claimed_at'] as String).toLocal()
          : null,
      notes: map['notes'] as String?,
      photoPath: map['photo_path'] as String?,
      pickupDate: _parseDateOnly(map['pickup_date']),
      takeMedicineTimes: _parseStringList(map['take_medicine_times']),
    );
  }

  /// Postgres `date` 欄位回傳形式可能是 `'2026-05-10'` 字串或 `DateTime`，兩種都接。
  static DateTime? _parseDateOnly(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = DateTime.parse(raw.trim());
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Postgres `text[]` 欄位 supabase-dart 會解析成 `List<dynamic>`；
  /// 同時容錯偶爾回傳純字串（例如 RPC 包成 csv）的情況。
  static List<String> _parseStringList(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      return raw
          .whereType<Object>()
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  /// 建立 Insert payload（給長輩端送出時用）。
  ///
  /// - [id]：若指定，須與 `prescriptions.id` 一致（志工確認時 upsert 同一 UUID）。
  /// - `created_at / status / claimed_by` 通常由 DB default／trigger 處理。
  ///
  /// [photoPath] 為照片在 Storage 的 object path，必須在呼叫端先把照片
  /// 上傳成功、確認拿到 path 後再傳進來；DB 端只記字串，不負責檔案。
  static Map<String, dynamic> insertPayload({
    /// 指定後才能與 `prescriptions.id` 對齊（志工確認時 upsert 同一張）。
    String? id,
    required String elderId,
    required String elderName,
    String? elderPhone,
    required String rawOcrText,
    String? hospitalName,
    String? photoPath,
  }) {
    return <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'elder_id': elderId,
      'elder_name': elderName,
      if (elderPhone != null && elderPhone.isNotEmpty)
        'elder_phone': elderPhone,
      'raw_ocr_text': rawOcrText,
      if (hospitalName != null && hospitalName.isNotEmpty)
        'hospital_name': hospitalName,
      if (photoPath != null && photoPath.isNotEmpty) 'photo_path': photoPath,
    };
  }
}
