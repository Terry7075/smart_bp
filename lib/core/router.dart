import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/admin/presentation/admin_dashboard_page.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_page.dart';
import 'package:smart_bp/features/family/presentation/family_home_page.dart';
import 'package:smart_bp/features/shop/presentation/shop_order_detail_page.dart';
import 'package:smart_bp/features/auth/login_page.dart';
import 'package:smart_bp/features/health_ocr/health_scan_page.dart';
import 'package:smart_bp/features/home/presentation/home_page.dart';
import 'package:smart_bp/features/learning/community_learning_page.dart';
import 'package:smart_bp/features/learning/hakka_culture_page.dart';
import 'package:smart_bp/features/medication/medication_checkin_page.dart';
import 'package:smart_bp/features/profile/profile_page.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_route_page.dart';
import 'package:smart_bp/features/shop/presentation/shop_elder_orders_page.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_chat_history_page.dart';
import 'package:smart_bp/features/shop/presentation/shop_demand_input_page.dart';
import 'package:smart_bp/features/shop/presentation/shop_price_page.dart';
import 'package:smart_bp/features/volunteer/volunteer_content_manage.dart';
import 'package:smart_bp/features/volunteer/volunteer_dashboard.dart';
import 'package:smart_bp/features/volunteer/volunteer_shop_orders_page.dart';
import 'package:smart_bp/features/transport/transport_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 綁定 Supabase `auth.onAuthStateChange`，登入／登出時通知 [GoRouter] 重跑 [GoRouter.redirect]。
///
/// 必須在 [Supabase.initialize] 之後才會被建立（見 [appRouter] 的延遲初始化）。
final class SupabaseAuthRefreshListenable extends ChangeNotifier {
  SupabaseAuthRefreshListenable() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

SupabaseAuthRefreshListenable? _supabaseAuthRefreshListenable;

/// 供 [GoRouter.refreshListenable] 使用（與 auth stream 同步）。
SupabaseAuthRefreshListenable get supabaseAuthRefreshListenable =>
    _supabaseAuthRefreshListenable ??= SupabaseAuthRefreshListenable();

/// 同步路由攔截：只負責「有沒有登入」這層分流。
///
/// 角色（長輩 vs 志工）的非同步分流由 [_RoleDecisionPage] 處理，這裡刻意保持
/// 同步，避免把 async profile 拉進 GoRouter redirect 造成 race condition。
String? _authRedirect(BuildContext context, GoRouterState state) {
  final loggedIn = Supabase.instance.client.auth.currentSession != null;
  final loc = state.matchedLocation;
  final onLoginPage = loc == '/login';

  if (!loggedIn && !onLoginPage) {
    return '/login';
  }
  if (loggedIn && onLoginPage) {
    // 登入成功 → 丟回根路徑，由角色決策頁再導去 /home 或 /volunteer-dashboard。
    return '/';
  }
  return null;
}

GoRouter? _appRouter;

/// 給需要全域 [Navigator] 的情境（例如通知點擊後 `context.go`）。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 應用程式全域路由（GoRouter）。於首次讀取時建立，請確保已先完成 `Supabase.initialize`。
GoRouter get appRouter =>
    _appRouter ??= GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: supabaseAuthRefreshListenable,
      redirect: _authRedirect,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        // 角色決策頁：每次登入後第一站，依 profile.role 分流到 /home 或
        // /volunteer-dashboard。
        GoRoute(
          path: '/',
          builder: (context, state) => const _RoleDecisionPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return HomePage(initialTab: tab.clamp(0, 5));
          },
        ),
        GoRoute(
          path: '/assistant',
          builder: (context, state) => const AssistantPage(),
        ),
        GoRoute(
          path: '/assistant/history',
          builder: (context, state) {
            final sid = state.uri.queryParameters['sessionId'];
            return AssistantChatHistoryPage(sessionId: sid);
          },
        ),
        GoRoute(
          path: '/volunteer-dashboard',
          builder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return VolunteerDashboard(initialTab: tab.clamp(0, 3));
          },
        ),
        GoRoute(
          path: '/shop',
          builder: (context, state) => const ShopRoutePage(),
        ),
        GoRoute(
          path: '/shop/demand-input',
          builder: (context, state) => const ShopDemandInputPage(),
        ),
        GoRoute(
          path: '/shop/prices',
          builder: (context, state) {
            final q = state.uri.queryParameters['q'];
            return ShopPricePage(initialQuery: q);
          },
        ),
        GoRoute(
          path: '/shop/orders',
          builder: (context, state) => const ShopElderOrdersPage(),
        ),
        GoRoute(
          path: '/shop/orders/:orderId',
          builder: (context, state) {
            final id = state.pathParameters['orderId'] ?? '';
            return ShopOrderDetailPage(orderId: id);
          },
        ),
        GoRoute(
          path: '/family/home',
          builder: (context, state) => const FamilyHomePage(),
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: '/volunteer/shop-orders',
          builder: (context, state) => const VolunteerShopOrdersPage(),
        ),
        GoRoute(
          path: '/health-scan',
          builder: (context, state) => const HealthScanPage(),
        ),
        GoRoute(
          path: '/community-learning',
          builder: (context, state) => const CommunityLearningPage(),
        ),
        GoRoute(
          path: '/hakka-culture',
          builder: (context, state) => const HakkaCulturePage(),
        ),
        GoRoute(
          path: '/volunteer-content-manage',
          builder: (context, state) => const VolunteerContentManagePage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/medication-checkin',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            final id = q['prescriptionId'] ?? '';
            final slot = q['slotTime'];
            return MedicationCheckinPage(
              prescriptionId: id,
              slotTime: slot,
            );
          },
        ),
        // 社區交通模組（/transport 前綴，依角色分流）
        ...buildTransportRoutes(),
      ],
    );

/// 登入後的角色決策頁（splash）。
///
/// 工作流程：
/// 1. 監聽 `profileProvider`（AsyncNotifier）的狀態。
/// 2. **Loading / 初始**：顯示啟動畫面 + 轉圈，避免在 profile 還沒抓回來前
///    就誤判 role。
/// 3. **Error**：顯示友善錯誤畫面 + 重試按鈕。
/// 4. **Data 抵達**：在 post-frame 內 `context.go(...)`：
///    - `profile.isVolunteer` → `/volunteer-dashboard`
///    - 其他（含 null / elder） → `/home`
///
/// 這裡不在 build() 裡直接 `context.go()`，而是用 [_navigated] 旗標 + listen
/// + post-frame，確保只在「first frame after data available」跳一次，避免
/// build 期間呼叫 navigation 造成例外。
class _RoleDecisionPage extends ConsumerStatefulWidget {
  const _RoleDecisionPage();

  @override
  ConsumerState<_RoleDecisionPage> createState() => _RoleDecisionPageState();
}

class _RoleDecisionPageState extends ConsumerState<_RoleDecisionPage> {
  bool _navigated = false;

  void _routeFor(AsyncValue<Profile?> async) {
    if (_navigated) return;
    if (async.isLoading) return;
    if (async.hasError) return;

    final profile = async.value;
    if (profile == null) return;

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null || profile.id != currentUid) return;

    final target = switch (profile.role) {
      Profile.kRoleVolunteer => '/volunteer-dashboard',
      Profile.kRoleFamily => '/family/home',
      Profile.kRoleAdmin => '/volunteer-dashboard?tab=3',
      Profile.kRoleDriver => '/transport',
      _ => '/home',
    };

    // 導航成功後才設 _navigated，避免 post-frame 時 widget 已 dispose 卻永遠卡住 splash。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigated = true;
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 監聽後續狀態變化（例如使用者登出又登入、或重試成功）。
    ref.listen<AsyncValue<Profile?>>(profileProvider, (_, next) {
      _routeFor(next);
    });

    final asyncProfile = ref.watch(profileProvider);
    // 也處理「進來時資料已 ready」的情境（例如熱重載、deep link）。
    _routeFor(asyncProfile);

    if (asyncProfile.hasError) {
      return _DecisionErrorView(
        error: asyncProfile.error!,
        onRetry: () {
          _navigated = false;
          ref.read(profileProvider.notifier).refresh();
        },
      );
    }

    return const _DecisionSplashView();
  }
}

class _DecisionSplashView extends StatelessWidget {
  const _DecisionSplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(height: 24),
            Text(
              '正在為您準備畫面…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionErrorView extends StatelessWidget {
  const _DecisionErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 72, color: Color(0xFFBF360C)),
                const SizedBox(height: 20),
                Text(
                  '讀取個人資料失敗：\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBF360C),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 28),
                  label: const Text(
                    '重新讀取',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
