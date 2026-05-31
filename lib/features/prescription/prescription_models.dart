/// 寫入 DB 時若 OCR 抓不到藥名，repository 使用的占位字串。
const String kMedicationNamePlaceholder = '（藥名請見藥袋或備註）';

/// 志工批次代領狀態（對應 `prescriptions.refill_status`）。
abstract final class RefillStatus {
  static const String none = 'none';
  static const String pendingCollection = 'pending_collection';
  static const String collecting = 'collecting';
  static const String outOfStock = 'out_of_stock';

  static String label(String status) => switch (status) {
        pendingCollection => '待收健保卡',
        collecting => '領藥中',
        outOfStock => '缺藥調貨中',
        _ => '一般',
      };
}

/// 長輩端「藥單 / 提醒管理」用的一筆紀錄（對應 Supabase `prescriptions`）。
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.userId,
    this.hospitalName,
    this.medicationName,
    this.pickupDate,
    this.takeMedicineTimes = const <String>[],
    this.medicationDays,
    this.baselineDate,
    this.pillAppearance,
    this.photoStoragePath,
    this.medicationsDetail = const [],
    this.refillStatus = RefillStatus.none,
    this.hasHealthCard = false,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? hospitalName;

  /// 藥品名稱（對應 `medication_name`；占位字串不算有效藥名）。
  final String? medicationName;

  /// 下次領藥日（純日期）。
  final DateTime? pickupDate;
  final List<String> takeMedicineTimes;
  final int? medicationDays;
  final DateTime? baselineDate;

  /// 藥丸外觀描述（例如「粉紅/圓形」），供打卡頁視覺化對照。
  final String? pillAppearance;

  /// 原始藥單照片在 `prescription-photos` bucket 的 object path。
  /// 供志工代領時核對原圖；私人 bucket 需用 signed URL 讀取。
  final String? photoStoragePath;

  /// Vision OCR 藥品明細（`medications_detail` JSON）。
  final List<Map<String, dynamic>> medicationsDetail;

  /// 批次代領狀態：`none` | `pending_collection` | `collecting` | `out_of_stock`。
  final String refillStatus;

  /// 志工是否已收妥該長輩健保卡與慢箋正本。
  final bool hasHealthCard;

  /// `active` | `cancelled` | `pending_verification` | …
  final String status;

  /// `ocr` | `volunteer`
  final String source;

  final DateTime createdAt;

  bool get isActive => status == 'active';

  bool get isPendingVerification => status == 'pending_verification';

  /// 可顯示給長輩的藥名（排除 DB 占位）。
  String? get displayMedicationName {
    final n = medicationName?.trim();
    if (n == null || n.isEmpty || n == kMedicationNamePlaceholder) return null;
    return n;
  }

  /// 外觀提示：優先 DB 欄位，否則從藥名推斷顏色／形狀關鍵字。
  String get displayPillHint {
    final p = pillAppearance?.trim();
    if (p != null && p.isNotEmpty) return p;
    return _inferPillHintFromText(medicationName ?? '');
  }

  static String _inferPillHintFromText(String text) {
    if (text.isEmpty) return '';
    final buf = StringBuffer();
    for (final c in ['粉紅', '紅', '白', '黃', '藍', '綠', '橘', '橙']) {
      if (text.contains(c)) buf.write(c);
    }
    for (final s in ['圓形', '圓', '橢圓', '長形', '長', '膠囊', '錠']) {
      if (text.contains(s)) {
        if (buf.isNotEmpty) buf.write('/');
        buf.write(s.contains('形') || s == '錠' ? s : '$s形');
      }
    }
    return buf.toString();
  }

  factory PrescriptionRecord.fromMap(Map<String, dynamic> map) {
    return PrescriptionRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      hospitalName: map['hospital_name'] as String?,
      medicationName: _parseOptionalString(map['medication_name']),
      pickupDate: _parseDate(map['pickup_date']),
      takeMedicineTimes: _parseStringList(map['take_medicine_times']),
      medicationDays: map['medication_days'] as int?,
      baselineDate: _parseDate(map['baseline_date']),
      pillAppearance: _parseOptionalString(map['pill_appearance']),
      photoStoragePath: _parseOptionalString(map['photo_storage_path']),
      medicationsDetail: _parseMedicationsDetail(map['medications_detail']),
      refillStatus: (map['refill_status'] as String?) ?? RefillStatus.none,
      hasHealthCard: map['has_health_card'] as bool? ?? false,
      status: (map['status'] as String?) ?? 'active',
      source: (map['source'] as String?) ?? 'ocr',
      createdAt:
          DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      if (hospitalName != null) 'hospital_name': hospitalName,
      if (medicationName != null) 'medication_name': medicationName,
      if (pickupDate != null) 'pickup_date': _formatIsoDate(pickupDate!),
      'take_medicine_times': takeMedicineTimes,
      if (medicationDays != null) 'medication_days': medicationDays,
      if (baselineDate != null) 'baseline_date': _formatIsoDate(baselineDate!),
      if (pillAppearance != null) 'pill_appearance': pillAppearance,
      'refill_status': refillStatus,
      'has_health_card': hasHealthCard,
      'status': status,
      'source': source,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  PrescriptionRecord copyWith({
    String? id,
    String? userId,
    String? hospitalName,
    String? medicationName,
    DateTime? pickupDate,
    List<String>? takeMedicineTimes,
    int? medicationDays,
    DateTime? baselineDate,
    String? pillAppearance,
    String? photoStoragePath,
    List<Map<String, dynamic>>? medicationsDetail,
    String? refillStatus,
    bool? hasHealthCard,
    String? status,
    String? source,
    DateTime? createdAt,
  }) {
    return PrescriptionRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hospitalName: hospitalName ?? this.hospitalName,
      medicationName: medicationName ?? this.medicationName,
      pickupDate: pickupDate ?? this.pickupDate,
      takeMedicineTimes: takeMedicineTimes ?? this.takeMedicineTimes,
      medicationDays: medicationDays ?? this.medicationDays,
      baselineDate: baselineDate ?? this.baselineDate,
      pillAppearance: pillAppearance ?? this.pillAppearance,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      medicationsDetail: medicationsDetail ?? this.medicationsDetail,
      refillStatus: refillStatus ?? this.refillStatus,
      hasHealthCard: hasHealthCard ?? this.hasHealthCard,
      status: status ?? this.status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String? _parseOptionalString(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = DateTime.parse(raw);
        return DateTime(d.year, d.month, d.day);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> _parseMedicationsDetail(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
