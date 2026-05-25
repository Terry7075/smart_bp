import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/admin_dashboard_stats.dart';
import 'package:mingde_transport/models/ride_request.dart';

void main() {
  test(
      'AdminDashboardStats counts global pending and today ride states separately',
      () {
    final stats = AdminDashboardStats.fromRides(
      rides: [
        _ride(id: 'pending-future', status: 'pending', date: '2026-05-25'),
        _ride(id: 'pending-today', status: 'pending', date: '2026-05-22'),
        _ride(id: 'matched-today', status: 'matched', date: '2026-05-22'),
        _ride(id: 'active-today', status: 'picked_up', date: '2026-05-22'),
        _ride(id: 'completed-today', status: 'completed', date: '2026-05-22'),
      ],
      today: DateTime(2026, 5, 22),
      pendingDriverCount: 3,
      pendingStandingRideCount: 2,
    );

    expect(stats.pendingRideCount, 2);
    expect(stats.todayRideCount, 4);
    expect(stats.todayMatchedCount, 1);
    expect(stats.inProgressCount, 1);
    expect(stats.pendingDriverCount, 3);
    expect(stats.pendingStandingRideCount, 2);
  });
}

RideRequest _ride({
  required String id,
  required String status,
  required String date,
}) {
  return RideRequest.fromJson({
    'id': id,
    'elder_id': 'elder-id',
    'pickup_location': '明德社區',
    'destination': '大千醫院',
    'custom_destination': null,
    'ride_date': date,
    'ride_time': '09:00:00',
    'passenger_count': 1,
    'need_return': false,
    'return_time': null,
    'note': null,
    'distance_km': null,
    'estimated_price': null,
    'status': status,
  });
}
