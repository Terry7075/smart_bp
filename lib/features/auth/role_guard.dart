import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';

/// 反向角色守門：確保「進到這頁的使用者」真的屬於 [requiredRole]。
///
/// 如果偵測到角色不符，會在 post-frame 內 `context.go(...)` 把人踢回對應的家：
/// - elder 誤入 volunteer 區 → /home
/// - volunteer 誤入 elder 區 → /volunteer-dashboard
///
/// 為什麼還需要這層？
/// 雖然根路徑 `_RoleDecisionPage` 已經會分流，但下列情境會繞過它：
/// - 註冊後 [profileProvider] 還沒抓到正確 role 就先導頁 (race condition)
/// - 使用者從 deep link 直接打開 `/home` 或 `/volunteer-dashboard`
/// - 之後角色被後台變更（升級為志工 / 取消志工）
///
/// 用法：直接把 page 內容包起來即可，例如：
/// ```dart
/// RoleGuard(
///   requiredRole: RoleGuardTarget.elder,
///   child: HomePageBody(),
/// )
/// ```
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
  });

  final RoleGuardTarget requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileProvider);

    // 監聽後續變化（例如 refresh 後拿到正確 role）
    ref.listen(profileProvider, (_, next) {
      _maybeRedirect(context, next);
    });

    // 第一次 build 也要檢一次（資料可能已 ready 在 cache 裡）
    _maybeRedirect(context, asyncProfile);

    // Loading / error 期間不擋畫面，照常顯示 child；真正錯誤角色時 _maybeRedirect
    // 會把人帶走，這裡不另外渲染 splash 以免閃爍。
    return child;
  }

  void _maybeRedirect(BuildContext context, AsyncValue<Profile?> async) {
    if (async.isLoading || async.hasError) return;
    final profile = async.value;
    if (profile == null) return;

    final shouldBeHere = switch (requiredRole) {
      RoleGuardTarget.elder => profile.isElder,
      RoleGuardTarget.volunteer => profile.isVolunteer,
    };
    if (shouldBeHere) return;

    final target = profile.isVolunteer ? '/volunteer-dashboard' : '/home';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(target);
    });
  }
}

enum RoleGuardTarget { elder, volunteer }
