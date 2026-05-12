import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'prescription_models.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(Supabase.instance.client);
});

/// 登入長輩的「使用中」藥單清單。
///
/// 隨 `authStateChangesProvider` 變更時自動重建，確保登出／換帳號會清空。
final activePrescriptionsProvider =
    FutureProvider.autoDispose<List<PrescriptionRecord>>((ref) async {
  ref.watch(authStateChangesProvider);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const [];

  final repo = ref.read(prescriptionRepositoryProvider);
  return repo.fetchActiveForUser(user.id);
});

class PrescriptionRepository {
  PrescriptionRepository(this._client);

  final SupabaseClient _client;

  /// `prescriptions.medication_name` 為 NOT NULL 時，辨識不到藥名改用此占位。
  static const String _fallbackMedicationName = '（藥名請見藥袋或備註）';

  static String _effectiveMedicationName(String? medicationName) {
    final t = medicationName?.trim() ?? '';
    return t.isNotEmpty ? t : _fallbackMedicationName;
  }

  Future<List<PrescriptionRecord>> fetchActiveForUser(String userId) async {
    final rows = await _client
        .from('prescriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return [
      for (final row in rows as List<dynamic>)
        PrescriptionRecord.fromMap(row as Map<String, dynamic>),
    ];
  }

  /// Realtime：該使用者名下所有藥單列（含 `pending_verification` / `active` 等）。
  Stream<List<PrescriptionRecord>> watchPrescriptionsForUser(String userId) {
    return _client
        .from('prescriptions')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final list = <PrescriptionRecord>[
            for (final raw in rows)
              PrescriptionRecord.fromMap(Map<String, dynamic>.from(raw)),
          ];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// 長輩將藥單送給志工協助時寫入，與 `volunteer_tasks.id` 相同 UUID。
  Future<void> insertPendingVerificationPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    DateTime? pickupDate,
    List<String> takeMedicineTimes = const [],
    String? rawNotes,
  }) async {
    final pickup = pickupDate ?? DateTime.now();
    await _client.from('prescriptions').insert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickup),
      'take_medicine_times': takeMedicineTimes,
      if (rawNotes != null && rawNotes.isNotEmpty) 'notes': rawNotes,
      'status': 'pending_verification',
      'source': 'volunteer',
    });
  }

  /// OCR 掃描完成後新增一筆（[id] 由呼叫端用 UUID v4 產生，方便預先排通知）。
  Future<void> insertOcrPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    required DateTime pickupDate,
    List<String> takeMedicineTimes = const [],
    int? medicationDays,
    DateTime? baselineDate,
    String? rawNotes,
  }) async {
    await _client.from('prescriptions').insert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickupDate),
      'take_medicine_times': takeMedicineTimes,
      if (medicationDays case final int d) 'medication_days': d,
      if (baselineDate case final DateTime b) 'baseline_date': _formatIsoDate(b),
      if (rawNotes != null && rawNotes.isNotEmpty) 'notes': rawNotes,
      'status': 'active',
      'source': 'ocr',
    });
  }

  /// 志工協助確認後同步建立／更新（UUID 與 `volunteer_tasks.id` 對齊）。
  Future<void> upsertVolunteerPrescription({
    required String id,
    required String userId,
    String? hospitalName,
    String? medicationName,
    required DateTime pickupDate,
    List<String> takeMedicineTimes = const [],
    int? medicationDays,
  }) async {
    await _client.from('prescriptions').upsert({
      'id': id,
      'user_id': userId,
      'medication_name': _effectiveMedicationName(medicationName),
      if (hospitalName != null && hospitalName.trim().isNotEmpty)
        'hospital_name': hospitalName.trim(),
      'pickup_date': _formatIsoDate(pickupDate),
      'take_medicine_times': takeMedicineTimes,
      if (medicationDays case final int d) 'medication_days': d,
      'status': 'active',
      'source': 'volunteer',
    });
  }

  Future<void> setCancelled(String prescriptionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    await _client
        .from('prescriptions')
        .update({'status': 'cancelled'})
        .eq('id', prescriptionId)
        .eq('user_id', uid);
  }

  Future<void> insertMedicationLog({
    required String prescriptionId,
    String? slotTime,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('尚未登入');

    await _client.from('medication_logs').insert({
      'user_id': uid,
      'prescription_id': prescriptionId,
      if (slotTime != null && slotTime.isNotEmpty) 'slot_time': slotTime,
    });
  }

  String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
