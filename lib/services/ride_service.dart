import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/driver.dart';
import '../models/driver_location.dart';
import '../models/profile.dart';
import '../models/ride_match.dart';
import '../models/ride_request.dart';
import '../models/ride_status.dart';

class RideService {
  RideService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<void> createRideRequest({
    required String pickupLocation,
    required String destination,
    required String? customDestination,
    required DateTime rideDate,
    required String rideTime,
    required int passengerCount,
    required bool needReturn,
    required String? returnTime,
    required String note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    await _client.from('ride_requests').insert({
      'elder_id': user.id,
      'pickup_location': pickupLocation,
      'destination': destination,
      'custom_destination': customDestination,
      'ride_date': rideDate.toIso8601String().split('T').first,
      'ride_time': rideTime,
      'passenger_count': passengerCount,
      'need_return': needReturn,
      'return_time': returnTime,
      'note': note.trim().isEmpty ? null : note.trim(),
    });
  }

  Stream<List<RideRequest>> watchMyRideRequests() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('elder_id', user.id)
        .order('ride_date', ascending: false)
        .map(
          (rows) => rows
              .map((row) => RideRequest.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Stream<List<RideRequest>> watchPendingRideRequests() {
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('ride_date')
        .order('ride_time')
        .map(
          (rows) => rows
              .map((row) => RideRequest.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<List<RideRequest>> fetchPendingRideRequests() async {
    final rows = await _client
        .from('ride_requests')
        .select()
        .eq('status', 'pending')
        .order('ride_date')
        .order('ride_time');
    return rows
        .map((row) => RideRequest.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> acceptRide(String rideRequestId) async {
    await _client.rpc('accept_ride', params: {'p_ride_request_id': rideRequestId});
  }

  Future<List<RideRequest>> fetchAdminPendingRideRequests() => fetchPendingRideRequests();

  Future<void> manualMatchRide({
    required String rideRequestId,
    required String driverId,
    required num distanceKm,
  }) async {
    await _client.rpc('manual_match_ride', params: {
      'p_ride_request_id': rideRequestId,
      'p_driver_id': driverId,
      'p_distance_km': distanceKm,
    });
  }

  Stream<List<RideMatch>> watchMatchesForDriver(String driverId) {
    return _client
        .from('ride_matches')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => RideMatch.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<RideRequest?> fetchRideRequestById(String rideRequestId) async {
    final row = await _client
        .from('ride_requests')
        .select()
        .eq('id', rideRequestId)
        .maybeSingle();
    if (row == null) return null;
    return RideRequest.fromJson(Map<String, dynamic>.from(row));
  }

  Future<RideMatch?> fetchMatchForRideRequest(String rideRequestId) async {
    final row = await _client
        .from('ride_matches')
        .select()
        .eq('ride_request_id', rideRequestId)
        .maybeSingle();
    if (row == null) return null;
    return RideMatch.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Driver?> fetchDriverById(String driverId) async {
    final row = await _client.from('drivers').select().eq('id', driverId).maybeSingle();
    if (row == null) return null;
    return Driver.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Profile?> fetchProfileById(String profileId) async {
    final row = await _client.from('profiles').select().eq('id', profileId).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateMatchStatus({
    required String matchId,
    required RideStatus status,
  }) async {
    await _client
        .from('ride_matches')
        .update({'status': status.databaseValue}).eq('id', matchId);
  }

  Future<void> cancelRideRequest({
    required String rideRequestId,
    String? reason,
  }) async {
    await _client.rpc('cancel_ride_request', params: {
      'p_ride_request_id': rideRequestId,
      'p_reason': reason,
    });
  }

  Future<void> rescheduleRideRequest({
    required String rideRequestId,
    required DateTime rideDate,
    required String rideTime,
    String? returnTime,
  }) async {
    await _client.rpc('reschedule_ride_request', params: {
      'p_ride_request_id': rideRequestId,
      'p_ride_date': rideDate.toIso8601String().split('T').first,
      'p_ride_time': rideTime,
      'p_return_time': returnTime,
    });
  }

  Future<void> reassignRide({
    required String rideRequestId,
    required String newDriverId,
  }) async {
    await _client.rpc('reassign_ride', params: {
      'p_ride_request_id': rideRequestId,
      'p_new_driver_id': newDriverId,
    });
  }

  Stream<DriverLocation?> watchDriverLocationForRide(String rideRequestId) {
    return _client
        .from('driver_locations')
        .stream(primaryKey: ['id'])
        .eq('ride_request_id', rideRequestId)
        .map((rows) => rows.isEmpty
            ? null
            : DriverLocation.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  Stream<List<RideRequest>> watchTodayRides() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _client
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('ride_date', today)
        .order('ride_time')
        .map(
          (rows) => rows
              .map((row) => RideRequest.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }
}
