/// 長輩端「藥單 / 提醒管理」用的一筆紀錄（對應 Supabase `prescriptions`）。
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.userId,
    this.hospitalName,
    this.pickupDate,
    this.takeMedicineTimes = const <String>[],
    this.medicationDays,
    this.baselineDate,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? hospitalName;

  /// 下次領藥日（純日期）。
  final DateTime? pickupDate;
  final List<String> takeMedicineTimes;
  final int? medicationDays;
  final DateTime? baselineDate;

  /// `active` | `cancelled` | `pending_verification` | …
  final String status;

  /// `ocr` | `volunteer`
  final String source;

  final DateTime createdAt;

  bool get isActive => status == 'active';

  bool get isPendingVerification => status == 'pending_verification';

  factory PrescriptionRecord.fromMap(Map<String, dynamic> map) {
    return PrescriptionRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      hospitalName: map['hospital_name'] as String?,
      pickupDate: _parseDate(map['pickup_date']),
      takeMedicineTimes: _parseStringList(map['take_medicine_times']),
      medicationDays: map['medication_days'] as int?,
      baselineDate: _parseDate(map['baseline_date']),
      status: (map['status'] as String?) ?? 'active',
      source: (map['source'] as String?) ?? 'ocr',
      createdAt:
          DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

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
}
