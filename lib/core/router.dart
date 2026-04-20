import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/login_page.dart';
import 'package:smart_bp/features/home/presentation/home_page.dart';
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

String? _authRedirect(BuildContext context, GoRouterState state) {
  final loggedIn = Supabase.instance.client.auth.currentSession != null;
  final onLoginPage = state.matchedLocation == '/login';

  if (!loggedIn && !onLoginPage) {
    return '/login';
  }
  if (loggedIn && onLoginPage) {
    return '/';
  }
  return null;
}

GoRouter? _appRouter;

/// 應用程式全域路由（GoRouter）。於首次讀取時建立，請確保已先完成 `Supabase.initialize`。
GoRouter get appRouter =>
    _appRouter ??= GoRouter(
      initialLocation: '/',
      refreshListenable: supabaseAuthRefreshListenable,
      redirect: _authRedirect,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
      ],
    );
