import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/driver.dart';
import '../models/ride_match.dart';
import '../models/ride_request.dart';

class GreedyMatchingService {
  GreedyMatchingService({SupabaseClient? client})
    : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Finds eligible online drivers, sorts by GPS distance, and commits the
  /// nearest driver as an automatic greedy match.
  Future<RideMatch?> matchDriver(String rideRequestId) async {
    final ride = await _fetchRideRequest(rideRequestId);
    if (ride == null ||
        ride.pickupLatitude == null ||
        ride.pickupLongitude == null) {
      return null;
    }

    final candidates = await _fetchEligibleDrivers(ride);
    final nearest = findNearestDriver(
      elderLatitude: ride.pickupLatitude!,
      elderLongitude: ride.pickupLongitude!,
      drivers: candidates,
    );
    if (nearest == null) return null;

    final distanceKm = calculateDistance(
      ride.pickupLatitude!,
      ride.pickupLongitude!,
      nearest.currentLatitude!,
      nearest.currentLongitude!,
    );

    final row = await _client.rpc(
      'apply_greedy_match',
      params: {
        'p_ride_request_id': ride.id,
        'p_driver_id': nearest.id,
        'p_distance_km': distanceKm,
      },
    );

    if (row == null) return null;
    return RideMatch.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Haversine Formula. Returns distance in kilometers.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final startLat = _toRadians(lat1);
    final endLat = _toRadians(lat2);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Greedy step: choose the currently nearest eligible driver.
  Driver? findNearestDriver({
    required double elderLatitude,
    required double elderLongitude,
    required List<Driver> drivers,
  }) {
    final locatedDrivers = drivers
        .where(
          (driver) =>
              driver.currentLatitude != null && driver.currentLongitude != null,
        )
        .toList();
    if (locatedDrivers.isEmpty) return null;

    locatedDrivers.sort((a, b) {
      final aDistance = calculateDistance(
        elderLatitude,
        elderLongitude,
        a.currentLatitude!,
        a.currentLongitude!,
      );
      final bDistance = calculateDistance(
        elderLatitude,
        elderLongitude,
        b.currentLatitude!,
        b.currentLongitude!,
      );
      return aDistance.compareTo(bDistance);
    });
    return locatedDrivers.first;
  }

  Future<RideRequest?> _fetchRideRequest(String rideRequestId) async {
    final row = await _client
        .from('ride_requests')
        .select()
        .eq('id', rideRequestId)
        .maybeSingle();
    if (row == null) return null;
    return RideRequest.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Driver>> _fetchEligibleDrivers(RideRequest ride) async {
    final minTime = _shiftTime(ride.rideTime, const Duration(minutes: -30));
    final maxTime = _shiftTime(ride.rideTime, const Duration(minutes: 30));

    final rows = await _client
        .from('drivers')
        .select()
        .eq('approval_status', 'approved')
        .eq('status', 'online')
        .gte('remaining_seats', ride.passengerCount)
        .eq('available_destination', ride.destination)
        .eq(
          'available_ride_date',
          ride.rideDate.toIso8601String().split('T').first,
        )
        .gte('available_ride_time', minTime)
        .lte('available_ride_time', maxTime)
        .not('current_latitude', 'is', null)
        .not('current_longitude', 'is', null);

    return rows
        .map((row) => Driver.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  String _shiftTime(String time, Duration delta) {
    final parts = time.split(':').map(int.parse).toList();
    final base = DateTime(
      2000,
      1,
      1,
      parts[0],
      parts[1],
      parts.length > 2 ? parts[2] : 0,
    );
    final shifted = base.add(delta);
    return [
      shifted.hour.toString().padLeft(2, '0'),
      shifted.minute.toString().padLeft(2, '0'),
      shifted.second.toString().padLeft(2, '0'),
    ].join(':');
  }

  double _toRadians(double degree) => degree * math.pi / 180;
}
