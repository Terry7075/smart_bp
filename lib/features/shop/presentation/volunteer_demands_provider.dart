import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/shared/debug/realtime_latency_tracker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 追蹤已通知過的草稿版本，避免 Realtime 重複震動。
final _volunteerDraftNotifyStateProvider =
    NotifierProvider<VolunteerDraftNotifyState, Map<String, DateTime>>(
  VolunteerDraftNotifyState.new,
);

class VolunteerDraftNotifyState extends Notifier<Map<String, DateTime>> {
  bool _baselineReady = false;

  @override
  Map<String, DateTime> build() => {};

  void setBaseline(Iterable<DemandRecord> records) {
    state = {for (final r in records) r.id: r.updatedAt};
    _baselineReady = true;
  }

  /// 回傳本次應通知的草稿（新單或 updated_at 變更）。
  List<DemandRecord> detectNewOrUpdated(List<DemandRecord> records) {
    if (!_baselineReady) return const [];
    final out = <DemandRecord>[];
    final next = Map<String, DateTime>.from(state);
    for (final r in records) {
      if (r.status != 'draft' || r.activeItems.isEmpty) continue;
      final prev = state[r.id];
      if (prev == null || prev.isBefore(r.updatedAt)) {
        out.add(r);
      }
      next[r.id] = r.updatedAt;
    }
    state = next;
    return out;
  }
}

/// 志工端：需求草稿 Realtime（第五章 Realtime 同步）。
final volunteerDemandDraftsProvider =
    StreamProvider.autoDispose<List<DemandRecord>>((ref) {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(demandRecordsRepositoryProvider);
  final client = Supabase.instance.client;
  var baselineSet = false;

  Future<List<DemandRecord>> reload() async {
    final result = await repo.listDraftsForVolunteer();
    ref.read(realtimeLatencyProvider.notifier).markReceived();

    final notify = ref.read(_volunteerDraftNotifyStateProvider.notifier);
    if (!baselineSet) {
      notify.setBaseline(result);
      baselineSet = true;
    } else {
      // 僅同步 baseline；長輩未送出草稿不推播志工（隱私）。
      notify.detectNewOrUpdated(result);
    }
    return result;
  }

  return client
      .from('demand_records')
      .stream(primaryKey: ['id'])
      .asyncMap((_) => reload());
});
