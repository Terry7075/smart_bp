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
        .map((rows) => rows.isEmpty ? null : Driver.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  Future<Driver?> fetchCurrentApplication() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client.from('drivers').select().eq('user_id', user.id).maybeSingle();
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
    if (user == null) throw StateError('User is not signed in.');

    await _client.from('drivers').insert({
      'user_id': user.id,
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'car_plate': carPlate.trim(),
      'car_model': carModel.trim().isEmpty ? null : carModel.trim(),
      'max_passengers': maxPassengers,
    });
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
        .update({'approval_status': approvalStatus}).eq('id', driverId);
  }
}
