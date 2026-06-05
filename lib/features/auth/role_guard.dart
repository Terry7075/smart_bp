import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    ref.listen(profileProvider, (_, next) {
      _maybeRedirect(context, next);
    });

    _maybeRedirect(context, asyncProfile);

    // profile 載入中 / 錯誤 / null / 角色不符時，不先 render 受保護畫面，
    // 避免長輩／志工儀表板「閃一下」才跳走。
    if (!_mayShowProtectedContent(asyncProfile)) {
      return const _RoleGuardSplash();
    }

    return child;
  }

  /// 是否可安全顯示 [child]：profile 已就緒、且 role 與本頁要求一致。
  bool _mayShowProtectedContent(AsyncValue<Profile?> async) {
    if (async.isLoading || async.hasError) return false;
    final profile = async.value;
    if (profile == null) return false;

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null || profile.id != currentUid) return false;

    return switch (requiredRole) {
      RoleGuardTarget.elder => profile.isElder,
      RoleGuardTarget.volunteer => profile.isVolunteerHub,
      RoleGuardTarget.family => profile.isFamily,
      RoleGuardTarget.admin => profile.isAdmin,
    };
  }

  void _maybeRedirect(BuildContext context, AsyncValue<Profile?> async) {
    if (async.isLoading || async.hasError) return;
    final profile = async.value;
    if (profile == null) return;

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null || profile.id != currentUid) return;

    final shouldBeHere = switch (requiredRole) {
      RoleGuardTarget.elder => profile.isElder,
      RoleGuardTarget.volunteer => profile.isVolunteerHub,
      RoleGuardTarget.family => profile.isFamily,
      RoleGuardTarget.admin => profile.isAdmin,
    };
    if (shouldBeHere) return;

    final target = switch (profile.role) {
      Profile.kRoleVolunteer => '/volunteer-dashboard',
      Profile.kRoleFamily => '/family/home',
      Profile.kRoleAdmin => '/volunteer-dashboard?tab=3',
      _ => '/home',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(target);
    });
  }
}

enum RoleGuardTarget { elder, volunteer, family, admin }

/// 角色確認前的占位畫面（與 router 的 splash 風格一致）。
class _RoleGuardSplash extends StatelessWidget {
  const _RoleGuardSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }
}
