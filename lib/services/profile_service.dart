import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Stream<Profile?> watchCurrentProfile() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(null);

    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .map((rows) => rows.isEmpty ? null : Profile.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  Future<Profile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateCurrentProfile({
    required String fullName,
    required String phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    await _client.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'emergency_contact_name': _nullableTrim(emergencyContactName),
      'emergency_contact_phone': _nullableTrim(emergencyContactPhone),
      'emergency_contact_relation': _nullableTrim(emergencyContactRelation),
    }).eq('id', user.id);
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
