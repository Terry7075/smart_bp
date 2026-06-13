import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/family/data/family_links_repository.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';

final familyLinksRepositoryProvider =
    Provider<FamilyLinksRepository>((ref) => const FamilyLinksRepository());

final familyLinksProvider = FutureProvider<List<FamilyElderLink>>((ref) async {
  final uid = ref.watch(authProvider)?.user.id;
  if (uid == null) return [];
  return ref.read(familyLinksRepositoryProvider).listMyLinks(uid);
});

/// 長者端：待我確認的家屬綁定請求（在長者首頁顯示同意 / 拒絕）。
final pendingFamilyRequestsProvider =
    FutureProvider<List<FamilyElderLink>>((ref) async {
  final uid = ref.watch(authProvider)?.user.id;
  if (uid == null) return [];
  return ref.read(familyLinksRepositoryProvider).listPendingForElder(uid);
});

/// 家屬查看綁定長輩訂單（Realtime，參數為長輩 user id）。
final familyElderOrdersProvider = familyElderOrdersStreamProvider;
