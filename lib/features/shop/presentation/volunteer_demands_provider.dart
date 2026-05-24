import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 志工端：需求草稿 Realtime（第五章 Realtime 同步）。
final volunteerDemandDraftsProvider =
    StreamProvider.autoDispose<List<DemandRecord>>((ref) {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(demandRecordsRepositoryProvider);
  final client = Supabase.instance.client;

  Future<List<DemandRecord>> reload() => repo.listDraftsForVolunteer();

  return client
      .from('demand_records')
      .stream(primaryKey: ['id'])
      .asyncMap((_) => reload());
});
