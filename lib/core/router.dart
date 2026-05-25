import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard_page.dart';
import '../features/admin/admin_driver_approval_page.dart';
import '../features/admin/admin_live_rides_page.dart';
import '../features/admin/admin_match_page.dart';
import '../features/admin/admin_standing_rides_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/role_gate_page.dart';
import '../features/driver/driver_active_ride_page.dart';
import '../features/driver/driver_application_page.dart';
import '../features/driver/driver_available_requests_page.dart';
import '../features/driver/create_driver_standing_ride_offer_page.dart';
import '../features/driver/driver_home_page.dart';
import '../features/driver/driver_pending_approval_page.dart';
import '../features/elder/create_ride_request_page.dart';
import '../features/elder/elder_home_page.dart';
import '../features/elder/elder_ride_detail_page.dart';
import '../features/elder/elder_ride_history_page.dart';
import '../features/elder/elder_standing_rides_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/profile_setup_page.dart';
import 'providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final profileState = ref.watch(currentProfileProvider);
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = authState.value?.session ?? authService.currentSession;
      final profile = profileState.value;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isSettingProfile = location == '/profile/setup';
      final isRoot = location == '/';
      final isCommonRoute =
          location == '/notifications' || location == '/profile';

      if (session == null) {
        return isLoggingIn ? null : '/login';
      }

      if (profileState.isLoading) return null;
      if (profile == null || !profile.isComplete) {
        return isSettingProfile ? null : '/profile/setup';
      }

      if (isLoggingIn || isRoot) {
        return switch (profile.role) {
          'admin' => '/admin',
          'driver' => '/driver',
          _ => '/elder',
        };
      }

      if (isCommonRoute || isSettingProfile) return null;
      if (profile.isAdmin && !location.startsWith('/admin')) return '/admin';
      if (profile.isDriver && !location.startsWith('/driver')) return '/driver';
      if (profile.isElder &&
          !location.startsWith('/elder') &&
          !location.startsWith('/driver/apply') &&
          !location.startsWith('/driver/pending')) {
        return '/elder';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const RoleGatePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
          path: '/profile/setup', builder: (_, __) => const ProfileSetupPage()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/elder', builder: (_, __) => const ElderHomePage()),
      GoRoute(
          path: '/elder/create',
          builder: (_, __) => const CreateRideRequestPage()),
      GoRoute(
          path: '/elder/standing',
          builder: (_, __) => const ElderStandingRidesPage()),
      GoRoute(
          path: '/elder/history',
          builder: (_, __) => const ElderRideHistoryPage()),
      GoRoute(
        path: '/elder/ride/:id',
        builder: (_, state) =>
            ElderRideDetailPage(rideRequestId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/driver/apply',
          builder: (_, __) => const DriverApplicationPage()),
      GoRoute(
          path: '/driver/pending',
          builder: (_, __) => const DriverPendingApprovalPage()),
      GoRoute(path: '/driver', builder: (_, __) => const DriverHomePage()),
      GoRoute(
        path: '/driver/available',
        builder: (_, __) => const DriverAvailableRequestsPage(),
      ),
      GoRoute(
        path: '/driver/standing/create',
        builder: (_, __) => const CreateDriverStandingRideOfferPage(),
      ),
      GoRoute(
        path: '/driver/active/:matchId/:rideRequestId',
        builder: (_, state) => DriverActiveRidePage(
          matchId: state.pathParameters['matchId']!,
          rideRequestId: state.pathParameters['rideRequestId']!,
        ),
      ),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardPage()),
      GoRoute(
        path: '/admin/drivers',
        builder: (_, __) => const AdminDriverApprovalPage(),
      ),
      GoRoute(path: '/admin/match', builder: (_, __) => const AdminMatchPage()),
      GoRoute(
          path: '/admin/standing',
          builder: (_, __) => const AdminStandingRidesPage()),
      GoRoute(
          path: '/admin/live', builder: (_, __) => const AdminLiveRidesPage()),
    ],
  );
});
