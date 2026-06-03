import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/standing_ride_request.dart';

void main() {
  group('StandingRideRequest', () {
    test('parses database rows and exposes selected weekday labels', () {
      final request = StandingRideRequest.fromJson({
        'id': 'standing-id',
        'elder_id': 'elder-id',
        'driver_id': 'driver-id',
        'driver_standing_ride_offer_id': 'offer-id',
        'pickup_location': 'Mingde Community',
        'destination': 'custom',
        'custom_destination': 'Hospital',
        'ride_time': '08:10:00',
        'passenger_count': 1,
        'need_return': true,
        'return_time': '17:40:00',
        'note': 'needs assistance',
        'service_weekdays': [1, 3, 5],
        'start_date': '2026-05-25',
        'end_date': '2026-06-30',
        'status': 'approved',
        'reviewed_by': 'admin-id',
        'reviewed_at': '2026-05-24T02:00:00Z',
        'rejection_reason': null,
        'created_at': '2026-05-22T01:00:00Z',
        'updated_at': '2026-05-23T01:00:00Z',
      });

      expect(request.displayDestination, 'Hospital');
      expect(request.serviceWeekdays, [1, 3, 5]);
      expect(request.serviceWeekdaysLabel, '週一、週三、週五');
      expect(request.driverId, 'driver-id');
      expect(request.driverStandingRideOfferId, 'offer-id');
      expect(request.status, StandingRideStatus.approved);
      expect(request.returnTime, '17:40:00');
    });

    test('parses database values for status', () {
      expect(
        StandingRideStatusX.fromDatabase('pending'),
        StandingRideStatus.pending,
      );
    });
  });
}
