import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class LocationTrackingService {
  LocationTrackingService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  Timer? _timer;

  bool get isTracking => _timer?.isActive ?? false;

  Future<void> startForegroundTracking(String rideMatchId) async {
    await _ensurePermission();
    await _sendLocation(rideMatchId);
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _sendLocation(rideMatchId),
    );
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Location service is disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for live tracking.');
    }
  }

  Future<void> _sendLocation(String rideMatchId) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await _client.rpc('upsert_driver_location', params: {
      'p_ride_match_id': rideMatchId,
      'p_latitude': position.latitude,
      'p_longitude': position.longitude,
      'p_accuracy_meters': position.accuracy,
      'p_heading': position.heading,
      'p_speed_mps': position.speed,
    });
  }
}
