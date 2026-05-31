import 'package:supabase_flutter/supabase_flutter.dart';

import 'health_monitoring_models.dart';

class HealthMonitoringRepository {
  HealthMonitoringRepository(this._client);

  final SupabaseClient _client;

  static const String _kProvider = 'google_health';

  // ---------------------------------------------------------------------------
  // health_connections
  // ---------------------------------------------------------------------------

  Future<HealthConnection?> fetchMyConnection() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from('health_connections')
        .select()
        .eq('user_id', uid)
        .eq('provider', _kProvider)
        .maybeSingle();

    if (row == null) return null;
    return HealthConnection.fromMap(Map<String, dynamic>.from(row));
  }

  /// Upsert connection status.  Only provided fields are written; omitted fields
  /// retain their existing values.  Pass `clearLastError: true` to null it out.
  Future<void> upsertConnection({
    required String userId,
    required String status,
    String? devicePlatform,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) async {
    final data = <String, dynamic>{
      'user_id': userId,
      'provider': _kProvider,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (devicePlatform != null) data['device_platform'] = devicePlatform;
    if (lastSyncAt != null) {
      data['last_sync_at'] = lastSyncAt.toUtc().toIso8601String();
    }
    if (lastError != null) {
      data['last_error'] = lastError;
    } else if (clearLastError) {
      data['last_error'] = null;
    }
    await _client
        .from('health_connections')
        .upsert(data, onConflict: 'user_id, provider');
  }

  // Token storage removed: google_sign_in SDK manages OAuth tokens internally.

  Stream<HealthConnection?> watchMyConnection(String userId) {
    return _client
        .from('health_connections')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final matching = rows
              .where((r) => (r['provider'] as String?) == _kProvider)
              .toList();
          if (matching.isEmpty) return null;
          return HealthConnection.fromMap(
              Map<String, dynamic>.from(matching.first));
        });
  }

  // ---------------------------------------------------------------------------
  // health_metrics
  // ---------------------------------------------------------------------------

  Future<void> batchUpsertMetrics(
      List<HealthMetricPoint> points, String userId) async {
    if (points.isEmpty) return;
    final rows = points.map((p) => p.toInsertRow(userId)).toList();
    await _client.from('health_metrics').upsert(
          rows,
          onConflict: 'user_id, metric_type, recorded_at, source',
        );
  }

  /// Each metric type: fetch most recent row.  Single query, grouped client-side.
  Future<Map<String, HealthMetricPoint>> fetchLatestMetricsForUser(
    String userId, {
    int lookback = 50,
  }) async {
    final rows = await _client
        .from('health_metrics')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(lookback);

    final result = <String, HealthMetricPoint>{};
    for (final r in rows as List) {
      final pt =
          HealthMetricPoint.fromMap(Map<String, dynamic>.from(r as Map));
      result.putIfAbsent(pt.metricType, () => pt);
      if (result.length == HealthMetricType.all.length) break;
    }
    return result;
  }

  Future<List<HealthMetricPoint>> fetchMetricHistory(
    String userId,
    String metricType, {
    int limit = 24,
  }) async {
    final rows = await _client
        .from('health_metrics')
        .select()
        .eq('user_id', userId)
        .eq('metric_type', metricType)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) =>
            HealthMetricPoint.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 志工：所有長輩最新指標摘要
  // ---------------------------------------------------------------------------

  Future<List<ElderHealthSummary>> fetchAllElderSummaries() async {
    final profiles = await _client
        .from('profiles')
        .select('id, name')
        .eq('role', 'elder');

    final connRows = await _client
        .from('health_connections')
        .select()
        .eq('provider', _kProvider);

    final connByUser = <String, HealthConnection>{};
    for (final r in connRows as List) {
      final c =
          HealthConnection.fromMap(Map<String, dynamic>.from(r as Map));
      connByUser[c.userId] = c;
    }

    final summaries = <ElderHealthSummary>[];
    for (final p in profiles as List) {
      final row = Map<String, dynamic>.from(p as Map);
      final uid = row['id'] as String;

      final latestRows = await _client
          .from('health_metrics')
          .select()
          .eq('user_id', uid)
          .order('recorded_at', ascending: false)
          .limit(20);

      final latestByType = <String, HealthMetricPoint>{};
      for (final r in latestRows as List) {
        final m =
            HealthMetricPoint.fromMap(Map<String, dynamic>.from(r as Map));
        latestByType.putIfAbsent(m.metricType, () => m);
      }

      summaries.add(ElderHealthSummary(
        elderId: uid,
        elderName: (row['name'] as String?) ?? '長輩',
        connection: connByUser[uid],
        latestByType: latestByType,
      ));
    }
    return summaries;
  }

  // ---------------------------------------------------------------------------
  // notification_outbox
  // ---------------------------------------------------------------------------

  Stream<List<NotificationOutboxItem>> watchPendingOutbox(String userId) {
    return _client
        .from('notification_outbox')
        .stream(primaryKey: const ['id'])
        .eq('target_user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) => (r['status'] as String?) == 'pending')
            .map((r) => NotificationOutboxItem.fromMap(
                  Map<String, dynamic>.from(r),
                ))
            .toList());
  }

  Future<void> markOutboxSent(String id) async {
    await _client.from('notification_outbox').update({
      'status': 'sent',
      'sent_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
