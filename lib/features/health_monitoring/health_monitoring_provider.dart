import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notification_service.dart';
import '../auth/auth_provider.dart';
import 'google_health_api_service.dart';
import 'health_monitoring_models.dart';
import 'health_monitoring_repository.dart';
import 'health_sync_service.dart';

// ---------------------------------------------------------------------------
// Singleton services
// ---------------------------------------------------------------------------

final healthMonitoringRepoProvider = Provider<HealthMonitoringRepository>((ref) {
  return HealthMonitoringRepository(Supabase.instance.client);
});

final googleHealthApiServiceProvider = Provider<GoogleHealthApiService>((ref) {
  return GoogleHealthApiService();
});

final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService(
    apiService: ref.read(googleHealthApiServiceProvider),
    repo: ref.read(healthMonitoringRepoProvider),
    client: Supabase.instance.client,
  );
});

// ---------------------------------------------------------------------------
// 長輩：自己的 health_connection Realtime stream
// ---------------------------------------------------------------------------

final myHealthConnectionProvider =
    StreamProvider.autoDispose<HealthConnection?>((ref) {
  ref.watch(authStateChangesProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return const Stream.empty();
  return ref.read(healthMonitoringRepoProvider).watchMyConnection(uid);
});

// ---------------------------------------------------------------------------
// 長輩：最新指標（每次 sync 後由 UI 呼叫 invalidate 重跑）
// ---------------------------------------------------------------------------

final myLatestMetricsProvider =
    FutureProvider.autoDispose<Map<String, HealthMetricPoint>>((ref) async {
  ref.watch(authStateChangesProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return const {};
  return ref.read(healthMonitoringRepoProvider).fetchLatestMetricsForUser(uid);
});

// ---------------------------------------------------------------------------
// 長輩：notification_outbox Realtime（收到 health_alert 通知後標 sent）
// ---------------------------------------------------------------------------

final myOutboxProvider =
    StreamProvider.autoDispose<List<NotificationOutboxItem>>((ref) {
  ref.watch(authStateChangesProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return const Stream.empty();
  return ref.read(healthMonitoringRepoProvider).watchPendingOutbox(uid);
});

// ---------------------------------------------------------------------------
// 志工：單一長輩的指標歷史（供 ElderHealthDetailSheet 切換指標類型用）
// ---------------------------------------------------------------------------

/// Family key: `(elderId, metricType)`
final elderMetricHistoryProvider = FutureProvider.autoDispose
    .family<List<HealthMetricPoint>, (String, String)>((ref, key) async {
  final (elderId, metricType) = key;
  return ref
      .read(healthMonitoringRepoProvider)
      .fetchMetricHistory(elderId, metricType);
});

// ---------------------------------------------------------------------------
// 志工：所有長輩摘要（手動 refresh；資料量小可接受）
// ---------------------------------------------------------------------------

final allElderHealthSummariesProvider =
    FutureProvider.autoDispose<List<ElderHealthSummary>>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.read(healthMonitoringRepoProvider).fetchAllElderSummaries();
});

// ---------------------------------------------------------------------------
// outbox 通知派發器（在 app 生命週期內監聽，見到 pending 立即顯示本機通知）
// ---------------------------------------------------------------------------

/// 在根 Widget 呼叫 `ref.watch(outboxDispatcherProvider)` 啟用。
///
/// 設計說明：
/// - 使用 `_processed` Set 防止同一筆 outbox 被重複推播（Realtime stream 在
///   `markOutboxSent` 後會重新 emit snapshot，可能包含尚未被過濾的舊項目）。
/// - 忽略超過 1 小時的 pending 通知，避免 App 重啟後大量補推歷史告警。
final outboxDispatcherProvider = StreamProvider.autoDispose<void>((ref) async* {
  ref.watch(authStateChangesProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;

  final repo = ref.read(healthMonitoringRepoProvider);
  final ns = NotificationService.instance;
  final processed = <String>{};

  await for (final items in repo.watchPendingOutbox(uid)) {
    for (final item in items) {
      if (processed.contains(item.id)) continue;

      final age = DateTime.now().difference(item.createdAt);
      if (age.inMinutes > 60) {
        processed.add(item.id);
        await repo.markOutboxSent(item.id);
        continue;
      }

      processed.add(item.id);
      await ns.showHealthAlert(
        outboxId: item.id,
        title: item.title,
        body: item.body,
        elderId: item.elderUserId,
      );
      await repo.markOutboxSent(item.id);
    }
  }
});
