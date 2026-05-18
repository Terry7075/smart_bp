import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/driver_location.dart';

void main() {
  test('DriverLocation parses realtime row', () {
    final location = DriverLocation.fromJson({
      'id': 'location-id',
      'ride_match_id': 'match-id',
      'ride_request_id': 'ride-id',
      'driver_id': 'driver-id',
      'latitude': 24.57,
      'longitude': 120.82,
      'accuracy_meters': 8.5,
      'heading': 90,
      'speed_mps': 3.2,
      'updated_at': '2026-05-16T01:00:00Z',
    });

    expect(location.rideMatchId, 'match-id');
    expect(location.latitude, 24.57);
    expect(location.longitude, 120.82);
    expect(location.accuracyMeters, 8.5);
  });
}
