// 穿戴監控領域模型（Google Health API → Supabase）。

abstract final class HealthMetricType {
  static const String heartRate = 'heart_rate';
  static const String steps = 'steps';
  static const String sleepMinutes = 'sleep_minutes';
  static const String bloodOxygen = 'blood_oxygen';
  static const String restingHeartRate = 'resting_heart_rate';

  static const List<String> all = [
    heartRate,
    steps,
    sleepMinutes,
    bloodOxygen,
    restingHeartRate,
  ];

  static String label(String type) => switch (type) {
        heartRate => '心率',
        steps => '步數',
        sleepMinutes => '睡眠',
        bloodOxygen => '血氧',
        restingHeartRate => '靜息心率',
        _ => type,
      };

  static String unitFor(String type) => switch (type) {
        heartRate => 'bpm',
        restingHeartRate => 'bpm',
        steps => '步',
        sleepMinutes => '分',
        bloodOxygen => '%',
        _ => '',
      };
}

abstract final class HealthConnectionStatus {
  static const String linked = 'linked';
  static const String revoked = 'revoked';
}

class HealthConnection {
  const HealthConnection({
    required this.id,
    required this.userId,
    required this.provider,
    required this.status,
    this.lastSyncAt,
    this.lastError,
    this.devicePlatform,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
  });

  final String id;
  final String userId;
  final String provider;
  final String status;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? devicePlatform;

  /// Google OAuth 2.0 access token (short-lived, ~1 h).
  final String? accessToken;

  /// Google OAuth 2.0 refresh token (long-lived, used to renew access token).
  final String? refreshToken;
  final DateTime? tokenExpiresAt;

  bool get isLinked => status == HealthConnectionStatus.linked;

  /// True when a refresh_token is stored (even if access_token is expired).
  bool get hasToken => refreshToken != null && refreshToken!.isNotEmpty;

  /// True when the stored access_token is still valid for at least 5 minutes.
  bool get isTokenValid =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      tokenExpiresAt != null &&
      DateTime.now()
          .isBefore(tokenExpiresAt!.subtract(const Duration(minutes: 5)));

  factory HealthConnection.fromMap(Map<String, dynamic> map) => HealthConnection(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        provider: (map['provider'] as String?) ?? 'google_health',
        status: (map['status'] as String?) ?? HealthConnectionStatus.revoked,
        lastSyncAt: _parseTs(map['last_sync_at']),
        lastError: map['last_error'] as String?,
        devicePlatform: map['device_platform'] as String?,
        accessToken: map['access_token'] as String?,
        refreshToken: map['refresh_token'] as String?,
        tokenExpiresAt: _parseTs(map['token_expires_at']),
      );
}

class HealthMetricPoint {
  const HealthMetricPoint({
    required this.metricType,
    required this.value,
    required this.recordedAt,
    this.unit,
    this.userId,
  });

  final String metricType;
  final double value;
  final DateTime recordedAt;
  final String? unit;
  final String? userId;

  factory HealthMetricPoint.fromMap(Map<String, dynamic> map) =>
      HealthMetricPoint(
        userId: map['user_id'] as String?,
        metricType: map['metric_type'] as String,
        value: (map['value'] as num).toDouble(),
        unit: map['unit'] as String?,
        recordedAt: DateTime.parse(map['recorded_at'] as String).toLocal(),
      );

  Map<String, dynamic> toInsertRow(String userId) => {
        'user_id': userId,
        'metric_type': metricType,
        'value': value,
        'unit': unit ?? HealthMetricType.unitFor(metricType),
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'source': 'google_health',
      };
}

class ElderHealthSummary {
  const ElderHealthSummary({
    required this.elderId,
    required this.elderName,
    this.connection,
    this.latestByType = const {},
  });

  final String elderId;
  final String elderName;
  final HealthConnection? connection;

  /// 每種指標的最新一筆。
  final Map<String, HealthMetricPoint> latestByType;

  bool get hasData => latestByType.isNotEmpty;
  bool get isLinked => connection?.isLinked == true;
}

class NotificationOutboxItem {
  const NotificationOutboxItem({
    required this.id,
    required this.targetUserId,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.elderUserId,
    this.payload = const {},
  });

  final String id;
  final String targetUserId;
  final String? elderUserId;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  factory NotificationOutboxItem.fromMap(Map<String, dynamic> map) =>
      NotificationOutboxItem(
        id: map['id'] as String,
        targetUserId: map['target_user_id'] as String,
        elderUserId: map['elder_user_id'] as String?,
        title: map['title'] as String,
        body: map['body'] as String,
        status: (map['status'] as String?) ?? 'pending',
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        payload: Map<String, dynamic>.from(
          (map['payload'] as Map?) ?? const {},
        ),
      );
}

DateTime? _parseTs(Object? raw) {
  if (raw == null) return null;
  return DateTime.parse(raw.toString()).toLocal();
}
