import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/presentation/shop_page.dart';

/// 柑仔店路由頁：僅限已登入且角色為長輩（[RoleGuardTarget.elder]）可進入。
///
/// 志工若透過 deep link 誤入 `/shop`，[RoleGuard] 會將其導向 `/volunteer-dashboard`。
class ShopRoutePage extends ConsumerWidget {
  const ShopRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: const ShopPage(),
    );
  }
}
