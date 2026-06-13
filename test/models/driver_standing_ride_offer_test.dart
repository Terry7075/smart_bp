import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/transport/models/driver_standing_ride_offer.dart';

void main() {
  test('DriverStandingRideOffer parses approved offer rows', () {
    final offer = DriverStandingRideOffer.fromJson({
      'id': 'offer-1',
      'driver_id': 'driver-1',
      'pickup_location': 'Mingde Community',
      'destination': 'Hospital',
      'custom_destination': null,
      'ride_time': '08:00:00',
      'passenger_count': 2,
      'need_return': true,
      'return_time': '12:00:00',
      'note': 'Can help boarding',
      'service_weekdays': [1, 3, 5],
      'start_date': '2026-06-01',
      'end_date': '2026-06-30',
      'status': 'approved',
      'reviewed_by': 'admin-1',
      'reviewed_at': '2026-05-25T10:00:00Z',
      'rejection_reason': null,
      'booked_by': null,
      'booked_at': null,
      'standing_ride_request_id': null,
      'created_at': '2026-05-25T09:00:00Z',
      'updated_at': '2026-05-25T10:00:00Z',
    });

    expect(offer.id, 'offer-1');
    expect(offer.status, DriverStandingRideOfferStatus.approved);
    expect(offer.serviceWeekdays, [1, 3, 5]);
    expect(offer.serviceWeekdaysLabel, '週一、週三、週五');
    expect(offer.displayDestination, 'Hospital');
  });
}
