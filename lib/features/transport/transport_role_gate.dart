import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 交通模組進入點（/transport）。
///
/// 依 smart_bp 的 [profileProvider] 角色把使用者導向交通模組的對應首頁：
/// - `driver` → 司機端 `/transport/driver`
/// - `volunteer` / `admin` → 交通管理端 `/transport/admin`
/// - 其餘（elder / family / null） → 叫車端 `/transport/elder`
///
/// 刻意不在交通模組重做登入／profile 強制設定，登入分流仍由 smart_bp 既有
/// [appRouter] 的 `_authRedirect` 與根路徑角色決策頁負責。
class TransportRoleGatePage extends ConsumerStatefulWidget {
  const TransportRoleGatePage({super.key});

  @override
  ConsumerState<TransportRoleGatePage> createState() =>
      _TransportRoleGatePageState();
}

class _TransportRoleGatePageState extends ConsumerState<TransportRoleGatePage> {
  bool _navigated = false;

  void _routeFor(AsyncValue<Profile?> async) {
    if (_navigated) return;
    if (async.isLoading || async.hasError) return;

    final profile = async.value;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null) return;
    if (profile != null && profile.id != currentUid) return;

    final target = switch (profile?.role) {
      Profile.kRoleDriver => '/transport/driver',
      Profile.kRoleVolunteer => '/transport/admin',
      Profile.kRoleAdmin => '/transport/admin',
      _ => '/transport/elder',
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigated = true;
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Profile?>>(profileProvider, (_, next) {
      _routeFor(next);
    });

    final asyncProfile = ref.watch(profileProvider);
    _routeFor(asyncProfile);

    if (asyncProfile.hasError) {
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
                    '讀取個人資料失敗：\n${asyncProfile.error}',
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
                    onPressed: () {
                      _navigated = false;
                      ref.read(profileProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh, size: 28),
                    label: const Text('重新讀取',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
              '正在進入社區交通…',
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
