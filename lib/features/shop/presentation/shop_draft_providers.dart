import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';

/// 長輩目前需求草稿（語音／常用物資寫入後、送出志工前）。
final elderDemandDraftProvider =
    FutureProvider.autoDispose<DemandRecord?>((ref) async {
  final uid = ref.watch(authProvider)?.user.id;
  if (uid == null) return null;
  return ref.read(demandRecordsRepositoryProvider).getOrCreateDraft(userId: uid);
});
