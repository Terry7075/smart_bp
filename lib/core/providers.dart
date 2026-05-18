import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/driver.dart';
import '../models/driver_location.dart';
import '../models/profile.dart';
import '../models/ride_feedback.dart';
import '../models/ride_match.dart';
import '../models/ride_request.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/driver_action_service.dart';
import '../services/feedback_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/ride_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());
final driverServiceProvider = Provider<DriverService>((ref) => DriverService());
final rideServiceProvider = Provider<RideService>((ref) => RideService());
final feedbackServiceProvider = Provider<FeedbackService>((ref) => FeedbackService());
final driverActionServiceProvider =
    Provider<DriverActionService>((ref) => DriverActionService());
final locationTrackingServiceProvider =
    Provider<LocationTrackingService>((ref) => LocationTrackingService());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);

final currentProfileProvider = StreamProvider<Profile?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(profileServiceProvider).watchCurrentProfile();
});

final currentDriverApplicationProvider = StreamProvider<Driver?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(driverServiceProvider).watchCurrentApplication();
});

final myRideRequestsProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideServiceProvider).watchMyRideRequests(),
);

final myNotificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationServiceProvider).watchMyNotifications(),
);

final pendingRideRequestsProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideServiceProvider).watchPendingRideRequests(),
);

final pendingDriverApplicationsProvider = StreamProvider<List<Driver>>(
  (ref) => ref.watch(driverServiceProvider).watchPendingApplications(),
);

final approvedDriversProvider = FutureProvider<List<Driver>>(
  (ref) => ref.watch(driverServiceProvider).fetchApprovedDrivers(),
);

final todayRidesProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideServiceProvider).watchTodayRides(),
);

final driverMatchesProvider =
    StreamProvider.family<List<RideMatch>, String>((ref, driverId) {
  return ref.watch(rideServiceProvider).watchMatchesForDriver(driverId);
});

final driverLocationForRideProvider =
    StreamProvider.family<DriverLocation?, String>((ref, rideRequestId) {
  return ref.watch(rideServiceProvider).watchDriverLocationForRide(rideRequestId);
});

final feedbackForRideProvider =
    StreamProvider.family<List<RideFeedback>, String>((ref, rideRequestId) {
  return ref.watch(feedbackServiceProvider).watchFeedbackForRide(rideRequestId);
});

final unresolvedIssuesProvider = StreamProvider<List<RideFeedback>>(
  (ref) => ref.watch(feedbackServiceProvider).watchUnresolvedIssues(),
);
