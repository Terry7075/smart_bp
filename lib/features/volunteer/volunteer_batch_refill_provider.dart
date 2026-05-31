import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';

import 'batch_refill_models.dart';

export 'batch_refill_models.dart';

/// 志工端：Realtime 監聽 active 藥單 → 10 天內 → 依 `hospital_name` 分群。
final volunteerBatchRefillGroupsProvider =
    StreamProvider.autoDispose<List<BatchRefillGroup>>((ref) {
  ref.watch(authStateChangesProvider);
  final repo = ref.read(prescriptionRepositoryProvider);
  return repo.watchBatchRefillGroups();
});
