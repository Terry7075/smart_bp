import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_health_api_service.dart';
import 'health_monitoring_models.dart';
import 'health_monitoring_repository.dart';

enum SyncResult { success, noPermission, noData, error }

class HealthSyncOutcome {
  const HealthSyncOutcome({
    required this.result,
    this.count = 0,
    this.message,
  });

  final SyncResult result;
  final int count;
  final String? message;

  bool get ok => result == SyncResult.success;
}

/// Sync flow: get fresh access token via google_sign_in →
/// call Google Health API → upsert metrics → update connection status.
class HealthSyncService {
  HealthSyncService({
    required GoogleHealthApiService apiService,
    required HealthMonitoringRepository repo,
    required SupabaseClient client,
  })  : _api = apiService,
        _repo = repo,
        _client = client;

  final GoogleHealthApiService _api;
  final HealthMonitoringRepository _repo;
  final SupabaseClient _client;

  /// Execute one full sync cycle.
  Future<HealthSyncOutcome> syncNow() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const HealthSyncOutcome(
        result: SyncResult.error,
        message: '請先登入帳號。',
      );
    }

    // ── 1. Get valid access token (silent first, interactive fallback) ──────
    final String accessToken;
    try {
      accessToken = await _api.getValidAccessToken();
    } catch (e) {
      await _repo.upsertConnection(
        userId: uid,
        status: HealthConnectionStatus.revoked,
        lastError: e.toString(),
      );
      return HealthSyncOutcome(
        result: SyncResult.noPermission,
        message: '授權已失效，請重新連結 Fitbit：$e',
      );
    }

    // ── 2. Fetch data from Google Health API ─────────────────────────────────
    final List<HealthMetricPoint> points;
    try {
      points = await _api.readRecent(accessToken: accessToken, hours: 24);
    } catch (e) {
      await _repo.upsertConnection(
        userId: uid,
        status: HealthConnectionStatus.linked,
        lastError: e.toString(),
      );
      return HealthSyncOutcome(
        result: SyncResult.error,
        message: '讀取 Google Health 資料失敗：$e',
      );
    }

    if (points.isEmpty) {
      await _repo.upsertConnection(
        userId: uid,
        status: HealthConnectionStatus.linked,
        lastSyncAt: DateTime.now(),
        clearLastError: true,
      );
      return const HealthSyncOutcome(
        result: SyncResult.noData,
        message: '過去 24 小時沒有新資料，連線正常。',
      );
    }

    // ── 3. Upsert metrics ────────────────────────────────────────────────────
    try {
      await _repo.batchUpsertMetrics(points, uid);
    } catch (e) {
      return HealthSyncOutcome(
        result: SyncResult.error,
        message: '上傳資料時出錯：$e',
      );
    }

    await _repo.upsertConnection(
      userId: uid,
      status: HealthConnectionStatus.linked,
      lastSyncAt: DateTime.now(),
      devicePlatform: 'fitbit',
      clearLastError: true,
    );

    return HealthSyncOutcome(
      result: SyncResult.success,
      count: points.length,
    );
  }
}
