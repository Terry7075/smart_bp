// Google Health API service (google_sign_in v7 + HTTP REST).
//
// ── Setup checklist (Google Cloud Console) ─────────────────────────────────
// 1. APIs & Services → enable "Google Health API".
// 2. OAuth consent screen → Data Access → add scopes:
//      .../auth/googlehealth.activity_and_fitness.readonly
//      .../auth/googlehealth.health_metrics_and_measurements.readonly
// 3. Credentials → Android OAuth 2.0 Client ID already created ✓
//    (package: com.example.smart_bp, SHA-1 registered)
// ──────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'health_monitoring_models.dart';

class GoogleHealthApiService {
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
    'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
  ];

  /// Data-type name → Google Health API path segment.
  /// ⚠️ Verify at https://developers.google.com/health/endpoints
  static const Map<String, String> _dataTypeMap = {
    HealthMetricType.heartRate: 'com.google.heart_rate.bpm',
    HealthMetricType.restingHeartRate: 'com.fitbit.resting_heart_rate',
    HealthMetricType.steps: 'com.google.step_count.delta',
    HealthMetricType.sleepMinutes: 'com.google.sleep.segment',
    HealthMetricType.bloodOxygen: 'com.google.oxygen_saturation',
  };

  // ── CONFIGURE: Web application OAuth 2.0 Client ID ───────────────────────
  // In Google Cloud Console → Credentials → Create → Web application
  // (No redirect URIs needed). Copy the Client ID here.
  static const String _serverClientId =
      '713785344684-53cj6c8mgm45f32sq2e7sb2d2010t5jr.apps.googleusercontent.com';
  // ──────────────────────────────────────────────────────────────────────────

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // serverClientId (Web app client) is required by google_sign_in v7 on Android.
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Authorization
  // ---------------------------------------------------------------------------

  /// Interactive sign-in + scope authorization. Returns the access token.
  Future<String> authorize() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final authz = await account.authorizationClient.authorizeScopes(_scopes);
    return authz.accessToken;
  }

  /// Return a valid access token without user interaction if possible.
  ///
  /// Uses the currently authorized user's cached token; only falls back to
  /// interactive sign-in when there is genuinely no active session.
  Future<String> getValidAccessToken() async {
    await _ensureInitialized();

    // Try to get a token from the current session without interaction.
    final authz = await GoogleSignIn.instance.authorizationClient
        .authorizationForScopes(_scopes);
    if (authz != null) return authz.accessToken;

    // No cached authorization — request interactively.
    return authorize();
  }

  /// Sign out and clear cached credentials.
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }

  // ---------------------------------------------------------------------------
  // Google Health API data fetch
  // ---------------------------------------------------------------------------

  /// Fetch health data for the past [hours] hours.
  Future<List<HealthMetricPoint>> readRecent({
    required String accessToken,
    int hours = 24,
  }) async {
    final start = DateTime.now().toUtc().subtract(Duration(hours: hours));
    final startIso = start.toIso8601String();
    final points = <HealthMetricPoint>[];

    for (final entry in _dataTypeMap.entries) {
      try {
        final batch = await _fetchDataType(
          accessToken: accessToken,
          apiDataType: entry.value,
          metricType: entry.key,
          startIso: startIso,
        );
        points.addAll(batch);
      } catch (_) {
        // Non-fatal: skip unavailable metric types.
      }
    }
    return points;
  }

  Future<List<HealthMetricPoint>> _fetchDataType({
    required String accessToken,
    required String apiDataType,
    required String metricType,
    required String startIso,
  }) async {
    final uri = Uri.https(
      'health.googleapis.com',
      '/v4/users/me/dataTypes/$apiDataType/dataPoints',
      {
        'filter': 'data_type.interval.start_time >= "$startIso"',
        'page_size': '100',
      },
    );

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    });

    if (response.statusCode == 401) {
      throw Exception('access_token 已過期，請重新整合。');
    }
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['dataPoints'] as List?) ?? [];

    final result = <HealthMetricPoint>[];
    for (final raw in items) {
      final pt = _parsePoint(raw as Map<String, dynamic>, metricType);
      if (pt != null) result.add(pt);
    }
    return result;
  }

  HealthMetricPoint? _parsePoint(
      Map<String, dynamic> map, String metricType) {
    try {
      final startRaw =
          map['startTime'] as String? ?? map['time'] as String?;
      if (startRaw == null) return null;
      final recordedAt = DateTime.parse(startRaw).toLocal();

      double? value;
      if (metricType == HealthMetricType.sleepMinutes) {
        final endRaw = map['endTime'] as String?;
        if (endRaw == null) return null;
        final dur =
            DateTime.parse(endRaw).difference(DateTime.parse(startRaw));
        value = dur.inMinutes.toDouble();
      } else {
        final vals = map['values'] as List?;
        final first = vals?.firstOrNull;
        if (first is Map) {
          value =
              ((first['fpVal'] ?? first['intVal']) as num?)?.toDouble();
        } else if (first is num) {
          value = first.toDouble();
        }
      }
      if (value == null) return null;

      return HealthMetricPoint(
        metricType: metricType,
        value: value,
        recordedAt: recordedAt,
        unit: HealthMetricType.unitFor(metricType),
      );
    } catch (_) {
      return null;
    }
  }
}
