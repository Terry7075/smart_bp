import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/driver.dart';

class DriverService {
  DriverService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Stream<Driver?> watchCurrentApplication() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(null);

    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map(
          (rows) => rows.isEmpty
              ? null
              : Driver.fromJson(Map<String, dynamic>.from(rows.first)),
        );
  }

  Future<Driver?> fetchCurrentApplication() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('drivers')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Driver.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> submitApplication({
    required String name,
    required String phone,
    required String address,
    required String carPlate,
    required String carModel,
    required int maxPassengers,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('請先登入');

    await _ensureProfile(
      userId: user.id,
      email: user.email ?? '',
      name: name.trim(),
      phone: phone.trim(),
    );

    final payload = <String, dynamic>{
      'user_id': user.id,
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'car_plate': carPlate.trim(),
      'car_model': carModel.trim().isEmpty ? null : carModel.trim(),
      'max_passengers': maxPassengers,
      'approval_status': 'pending',
      'remaining_seats': maxPassengers,
      'status': 'offline',
    };

    try {
      await _client.from('drivers').insert(payload);
    } on PostgrestException catch (error) {
      if (!_isDriverCapacitySchemaMissing(error)) rethrow;

      // Allows the application to submit while an older database schema is
      // waiting for the remaining_seats/status migration to be applied.
      final compatiblePayload = Map<String, dynamic>.from(payload)
        ..remove('remaining_seats')
        ..remove('status');
      await _client.from('drivers').insert(compatiblePayload);
    }
  }

  Future<void> _ensureProfile({
    required String userId,
    required String email,
    required String name,
    required String phone,
  }) async {
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    if (profile != null) return;

    await _client.from('profiles').insert({
      'id': userId,
      'email': email,
      'full_name': name,
      'phone': phone,
      'role': 'elder',
    });
  }

  bool _isDriverCapacitySchemaMissing(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('remaining_seats') ||
        message.contains('status') && message.contains('schema cache') ||
        error.code == 'PGRST204' ||
        error.code == 'PGRST205';
  }

  Stream<List<Driver>> watchPendingApplications() {
    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('approval_status', 'pending')
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => Driver.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Stream<List<Driver>> watchApprovedDrivers() {
    return _client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('approval_status', 'approved')
        .order('name')
        .map(
          (rows) => rows
              .map((row) => Driver.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<List<Driver>> fetchPendingApplications() async {
    final rows = await _client
        .from('drivers')
        .select()
        .eq('approval_status', 'pending')
        .order('created_at');
    return rows
        .map((row) => Driver.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Driver>> fetchApprovedDrivers() async {
    final rows = await _client
        .from('drivers')
        .select()
        .eq('approval_status', 'approved')
        .order('name');
    return rows
        .map((row) => Driver.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> reviewApplication({
    required String driverId,
    required String approvalStatus,
  }) async {
    await _client
        .from('drivers')
        .update({'approval_status': approvalStatus})
        .eq('id', driverId);
  }
}
