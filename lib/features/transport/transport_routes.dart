import 'package:go_router/go_router.dart';

import 'transport_role_gate.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_driver_approval_page.dart';
import 'features/admin/admin_fixed_ride_suggestions_page.dart';
import 'features/admin/admin_live_rides_page.dart';
import 'features/admin/admin_match_page.dart';
import 'features/admin/admin_standing_rides_page.dart';
import 'features/driver/create_driver_standing_ride_offer_page.dart';
import 'features/driver/driver_active_ride_page.dart';
import 'features/driver/driver_application_page.dart';
import 'features/driver/driver_available_requests_page.dart';
import 'features/driver/driver_home_page.dart';
import 'features/driver/driver_pending_approval_page.dart';
import 'features/elder/create_ride_request_page.dart';
import 'features/elder/elder_home_page.dart';
import 'features/elder/elder_ride_detail_page.dart';
import 'features/elder/elder_ride_history_page.dart';
import 'features/elder/elder_standing_rides_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_setup_page.dart';

/// 社區交通模組的路由（全部掛在 `/transport` 前綴下），併進 smart_bp 的
/// 全域 `appRouter`。進入點 `/transport` 由 [TransportRoleGatePage] 依角色分流。
List<RouteBase> buildTransportRoutes() => [
  GoRoute(path: '/transport', builder: (_, _) => const TransportRoleGatePage()),
  // 共用頁
  GoRoute(
    path: '/transport/notifications',
    builder: (_, _) => const NotificationsPage(),
  ),
  GoRoute(path: '/transport/profile', builder: (_, _) => const ProfilePage()),
  GoRoute(
    path: '/transport/profile/setup',
    builder: (_, _) => const ProfileSetupPage(),
  ),
  // 長者 / 叫車端
  GoRoute(path: '/transport/elder', builder: (_, _) => const ElderHomePage()),
  GoRoute(
    path: '/transport/elder/create',
    builder: (_, _) => const CreateRideRequestPage(),
  ),
  GoRoute(
    path: '/transport/elder/standing',
    builder: (_, _) => const ElderStandingRidesPage(),
  ),
  GoRoute(
    path: '/transport/elder/history',
    builder: (_, _) => const ElderRideHistoryPage(),
  ),
  GoRoute(
    path: '/transport/elder/ride/:id',
    builder: (_, state) =>
        ElderRideDetailPage(rideRequestId: state.pathParameters['id']!),
  ),
  // 司機端
  GoRoute(path: '/transport/driver', builder: (_, _) => const DriverHomePage()),
  GoRoute(
    path: '/transport/driver/apply',
    builder: (_, _) => const DriverApplicationPage(),
  ),
  GoRoute(
    path: '/transport/driver/pending',
    builder: (_, _) => const DriverPendingApprovalPage(),
  ),
  GoRoute(
    path: '/transport/driver/available',
    builder: (_, _) => const DriverAvailableRequestsPage(),
  ),
  GoRoute(
    path: '/transport/driver/standing/create',
    builder: (_, _) => const CreateDriverStandingRideOfferPage(),
  ),
  GoRoute(
    path: '/transport/driver/active/:matchId/:rideRequestId',
    builder: (_, state) => DriverActiveRidePage(
      matchId: state.pathParameters['matchId']!,
      rideRequestId: state.pathParameters['rideRequestId']!,
    ),
  ),
  // 交通管理端（admin / volunteer）
  GoRoute(
    path: '/transport/admin',
    builder: (_, _) => const AdminDashboardPage(),
  ),
  GoRoute(
    path: '/transport/admin/drivers',
    builder: (_, _) => const AdminDriverApprovalPage(),
  ),
  GoRoute(
    path: '/transport/admin/standing',
    builder: (_, _) => const AdminStandingRidesPage(),
  ),
  GoRoute(
    path: '/transport/admin/fixed-suggestions',
    builder: (_, _) => const AdminFixedRideSuggestionsPage(),
  ),
  GoRoute(
    path: '/transport/admin/match',
    builder: (_, _) => const AdminMatchPage(),
  ),
  GoRoute(
    path: '/transport/admin/live',
    builder: (_, _) => const AdminLiveRidesPage(),
  ),
];
