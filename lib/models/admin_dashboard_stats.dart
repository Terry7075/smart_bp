import 'ride_request.dart';
import 'ride_status.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.pendingRideCount,
    required this.todayRideCount,
    required this.todayMatchedCount,
    required this.inProgressCount,
    required this.pendingDriverCount,
    required this.pendingStandingRideCount,
  });

  final int pendingRideCount;
  final int todayRideCount;
  final int todayMatchedCount;
  final int inProgressCount;
  final int pendingDriverCount;
  final int pendingStandingRideCount;

  factory AdminDashboardStats.fromRides({
    required List<RideRequest> rides,
    required DateTime today,
    required int pendingDriverCount,
    required int pendingStandingRideCount,
  }) {
    final date = DateTime(today.year, today.month, today.day);
    final todayRides =
        rides.where((ride) => _sameDate(ride.rideDate, date)).toList();

    return AdminDashboardStats(
      pendingRideCount:
          rides.where((ride) => ride.status == RideStatus.pending).length,
      todayRideCount: todayRides.length,
      todayMatchedCount:
          todayRides.where((ride) => ride.status == RideStatus.matched).length,
      inProgressCount: rides
          .where((ride) =>
              ride.status == RideStatus.pickedUp ||
              ride.status == RideStatus.onTheWay)
          .length,
      pendingDriverCount: pendingDriverCount,
      pendingStandingRideCount: pendingStandingRideCount,
    );
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
