import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:smart_bp/features/volunteer/volunteer_task_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 從 Supabase 載入長輩小幫手所需的即時資料。
class AssistantSnapshotLoader {
  const AssistantSnapshotLoader(this._ref);

  final Ref _ref;

  Future<AssistantSnapshot> load() async {
    final profile = _ref.read(profileProvider).value;
    final session = _ref.read(authProvider);
    final userId = session?.user.id;

    final task = await _loadLatestPrescription(userId);
    final orders = await _loadRecentOrders(userId);

    return AssistantSnapshot(
      displayName: profile?.name,
      latestPrescription: task,
      recentOrders: orders,
      loadedAt: DateTime.now(),
    );
  }

  Future<VolunteerTask?> _loadLatestPrescription(String? userId) async {
    final cached = _ref.read(latestPrescriptionStreamProvider).value;
    if (cached != null) return cached;
    if (userId == null || userId.isEmpty) return null;

    final raw = await Supabase.instance.client
        .from('volunteer_tasks')
        .select()
        .eq('elder_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    final list = List<dynamic>.from(raw as List? ?? const []);
    if (list.isEmpty) return null;
    final row = list.first;
    if (row is! Map) return null;
    return VolunteerTask.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<ShopOrderListRow>> _loadRecentOrders(String? userId) async {
    if (userId == null || userId.isEmpty) return const [];
    final repo = _ref.read(shopOrdersRepositoryProvider);
    return repo.listOrdersWithItemsForElder(userId: userId, limit: 5);
  }
}

final assistantSnapshotLoaderProvider = Provider<AssistantSnapshotLoader>(
  (ref) => AssistantSnapshotLoader(ref),
);
