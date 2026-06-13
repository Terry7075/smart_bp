import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/driver.dart';
import '../models/driver_location.dart';
import '../models/driver_standing_ride_offer.dart';
import '../models/fixed_ride_suggestion.dart';
import '../models/profile.dart';
import '../models/ride_feedback.dart';
import '../models/ride_match.dart';
import '../models/ride_request.dart';
import '../models/standing_ride_request.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../services/driver_action_service.dart';
import '../services/feedback_service.dart';
import '../services/fixed_ride_prediction_service.dart';
import '../services/greedy_matching_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/ride_service.dart';
import '../services/standing_ride_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(),
);
final driverServiceProvider = Provider<DriverService>((ref) => DriverService());
final rideServiceProvider = Provider<RideService>((ref) => RideService());
final greedyMatchingServiceProvider = Provider<GreedyMatchingService>(
  (ref) => GreedyMatchingService(),
);
final fixedRidePredictionServiceProvider = Provider<FixedRidePredictionService>(
  (ref) => FixedRidePredictionService(),
);
final standingRideServiceProvider = Provider<StandingRideService>(
  (ref) => StandingRideService(),
);
final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(),
);
final driverActionServiceProvider = Provider<DriverActionService>(
  (ref) => DriverActionService(),
);
final locationTrackingServiceProvider = Provider<LocationTrackingService>(
  (ref) => LocationTrackingService(),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

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

final adminRideRequestsProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideServiceProvider).watchAdminRideRequests(),
);

final pendingDriverApplicationsProvider = StreamProvider<List<Driver>>(
  (ref) => ref.watch(driverServiceProvider).watchPendingApplications(),
);

final approvedDriversProvider = StreamProvider<List<Driver>>(
  (ref) => ref.watch(driverServiceProvider).watchApprovedDrivers(),
);

final todayRidesProvider = StreamProvider<List<RideRequest>>(
  (ref) => ref.watch(rideServiceProvider).watchTodayRides(),
);

final myStandingRideRequestsProvider =
    StreamProvider<List<StandingRideRequest>>(
      (ref) =>
          ref.watch(standingRideServiceProvider).watchMyStandingRideRequests(),
    );

final myFixedRideSuggestionsProvider =
    StreamProvider<List<FixedRideSuggestion>>(
      (ref) => ref
          .watch(fixedRidePredictionServiceProvider)
          .watchMyPendingSuggestions(),
    );

final fixedRideAnalysisProvider = FutureProvider<List<FixedRideSuggestion>>((
  ref,
) {
  ref.watch(myRideRequestsProvider);
  return ref.watch(fixedRidePredictionServiceProvider).analyzeRideHistory();
});

final approvedDriverStandingRideOffersProvider =
    StreamProvider<List<DriverStandingRideOffer>>(
      (ref) => ref
          .watch(standingRideServiceProvider)
          .watchApprovedDriverStandingRideOffers(),
    );

final myDriverStandingRideOffersProvider =
    StreamProvider<List<DriverStandingRideOffer>>(
      (ref) => ref
          .watch(standingRideServiceProvider)
          .watchMyDriverStandingRideOffers(),
    );

final adminDriverStandingRideOffersProvider =
    StreamProvider<List<DriverStandingRideOffer>>(
      (ref) => ref
          .watch(standingRideServiceProvider)
          .watchAdminDriverStandingRideOffers(),
    );

final pendingDriverStandingRideOffersProvider =
    StreamProvider<List<DriverStandingRideOffer>>(
      (ref) => ref
          .watch(standingRideServiceProvider)
          .watchPendingDriverStandingRideOffers(),
    );

final adminFixedRideSuggestionsProvider =
    FutureProvider<List<FixedRideSuggestion>>(
      (ref) =>
          ref.watch(fixedRidePredictionServiceProvider).fetchAdminSuggestions(),
    );

final adminDashboardStatsProvider = Provider<AsyncValue<AdminDashboardStats>>((
  ref,
) {
  final rides = ref.watch(adminRideRequestsProvider);
  final pendingDrivers = ref.watch(pendingDriverApplicationsProvider);
  final pendingStandingRideOffers = ref.watch(
    pendingDriverStandingRideOffersProvider,
  );

  if (rides.hasError) {
    return AsyncValue.error(rides.error!, rides.stackTrace!);
  }
  if (pendingDrivers.hasError) {
    return AsyncValue.error(pendingDrivers.error!, pendingDrivers.stackTrace!);
  }
  if (pendingStandingRideOffers.hasError) {
    return AsyncValue.error(
      pendingStandingRideOffers.error!,
      pendingStandingRideOffers.stackTrace!,
    );
  }
  if (rides.isLoading ||
      pendingDrivers.isLoading ||
      pendingStandingRideOffers.isLoading) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    AdminDashboardStats.fromRides(
      rides: rides.value ?? const [],
      today: DateTime.now(),
      pendingDriverCount: pendingDrivers.value?.length ?? 0,
      pendingStandingRideCount: pendingStandingRideOffers.value?.length ?? 0,
    ),
  );
});

final driverMatchesProvider = StreamProvider.family<List<RideMatch>, String>((
  ref,
  driverId,
) {
  return ref.watch(rideServiceProvider).watchMatchesForDriver(driverId);
});

final driverLocationForRideProvider =
    StreamProvider.family<DriverLocation?, String>((ref, rideRequestId) {
      return ref
          .watch(rideServiceProvider)
          .watchDriverLocationForRide(rideRequestId);
    });

final feedbackForRideProvider =
    StreamProvider.family<List<RideFeedback>, String>((ref, rideRequestId) {
      return ref
          .watch(feedbackServiceProvider)
          .watchFeedbackForRide(rideRequestId);
    });

final unresolvedIssuesProvider = StreamProvider<List<RideFeedback>>(
  (ref) => ref.watch(feedbackServiceProvider).watchUnresolvedIssues(),
);
