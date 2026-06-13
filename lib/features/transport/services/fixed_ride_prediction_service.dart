import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/fixed_ride_suggestion.dart';

class FixedRidePredictionService {
  FixedRidePredictionService({SupabaseClient? client})
    : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<List<FixedRideSuggestion>> analyzeRideHistory() async {
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')
        .first;

    final rows = await _client
        .from('ride_requests')
        .select(
          'id, elder_id, destination, custom_destination, ride_date, ride_time, status',
        )
        .gte('ride_date', since)
        .neq('status', 'cancelled')
        .order('ride_date');

    final patterns = detectFixedRidePattern(
      rows.map((row) => Map<String, dynamic>.from(row)).toList(),
    );

    final suggestions = <FixedRideSuggestion>[];
    for (final pattern in patterns) {
      final suggestion = await createFixedRideSuggestion(pattern);
      if (suggestion != null) suggestions.add(suggestion);
    }
    return suggestions;
  }

  List<FixedRidePattern> detectFixedRidePattern(
    List<Map<String, dynamic>> rideRows,
  ) {
    final groups = <String, List<_RideHistoryPoint>>{};

    for (final row in rideRows) {
      final userId = row['elder_id'] as String;
      final customDestination = row['custom_destination'] as String?;
      final destination = customDestination?.trim().isNotEmpty == true
          ? customDestination!
          : row['destination'] as String;
      final rideDate = DateTime.parse(row['ride_date'] as String);
      final rideTime = row['ride_time'] as String;
      final key = '$userId|$destination|${rideDate.weekday}';

      groups
          .putIfAbsent(key, () => [])
          .add(
            _RideHistoryPoint(
              userId: userId,
              destination: destination,
              weekday: rideDate.weekday,
              minuteOfDay: _timeToMinuteOfDay(rideTime),
            ),
          );
    }

    final patterns = <FixedRidePattern>[];
    for (final points in groups.values) {
      if (points.length < 3) continue;

      _Cluster? best;
      for (final center in points) {
        final clustered = points
            .where(
              (point) => (point.minuteOfDay - center.minuteOfDay).abs() <= 30,
            )
            .toList();
        if (clustered.length < 3) continue;

        final cluster = _Cluster(clustered);
        if (best == null || cluster.points.length > best.points.length) {
          best = cluster;
        }
      }

      if (best == null) continue;
      final first = best.points.first;
      patterns.add(
        FixedRidePattern(
          userId: first.userId,
          destination: first.destination,
          weekday: first.weekday,
          suggestedTime: _minuteOfDayToTime(best.averageMinuteOfDay),
          occurrenceCount: best.points.length,
        ),
      );
    }

    return patterns;
  }

  Future<FixedRideSuggestion?> createFixedRideSuggestion(
    FixedRidePattern pattern,
  ) async {
    final existing = await _client
        .from('fixed_ride_suggestions')
        .select()
        .eq('user_id', pattern.userId)
        .eq('destination', pattern.destination)
        .eq('weekday', pattern.weekday)
        .inFilter('status', ['pending', 'accepted'])
        .maybeSingle();

    if (existing != null) {
      return FixedRideSuggestion.fromJson(Map<String, dynamic>.from(existing));
    }

    final row = await _client
        .from('fixed_ride_suggestions')
        .insert({
          'user_id': pattern.userId,
          'destination': pattern.destination,
          'weekday': pattern.weekday,
          'suggested_time': pattern.suggestedTime,
          'occurrence_count': pattern.occurrenceCount,
          'status': FixedRideSuggestionStatus.pending.databaseValue,
        })
        .select()
        .single();

    return FixedRideSuggestion.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> confirmFixedRideSuggestion(String suggestionId) async {
    await _client
        .from('fixed_ride_suggestions')
        .update({
          'status': FixedRideSuggestionStatus.accepted.databaseValue,
          'confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', suggestionId);
  }

  Future<void> rejectFixedRideSuggestion(String suggestionId) async {
    await _client
        .from('fixed_ride_suggestions')
        .update({'status': FixedRideSuggestionStatus.rejected.databaseValue})
        .eq('id', suggestionId);
  }

  Stream<List<FixedRideSuggestion>> watchMyPendingSuggestions() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('fixed_ride_suggestions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => _parseSuggestionRows(
            rows
                .where(
                  (row) =>
                      row['status'] ==
                      FixedRideSuggestionStatus.pending.databaseValue,
                )
                .toList(),
          ),
        );
  }

  Stream<List<FixedRideSuggestion>> watchAdminSuggestions() {
    return _client
        .from('fixed_ride_suggestions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(_parseSuggestionRows);
  }

  Future<List<FixedRideSuggestion>> fetchAdminSuggestions() async {
    debugPrint('開始載入固定接送建議');
    try {
      final rows = await _client
          .from('fixed_ride_suggestions')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final suggestions = _parseSuggestionRows(
        rows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
      debugPrint('Supabase 查詢固定接送建議成功，資料筆數：${suggestions.length}');
      return suggestions;
    } on PostgrestException catch (error, stackTrace) {
      final message = error.code == 'PGRST205'
          ? 'Supabase 尚未建立 fixed_ride_suggestions 資料表，請先執行 migration。'
          : 'Supabase 查詢固定接送建議失敗：${error.message}';
      debugPrint('$message code=${error.code}');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception(message);
    } catch (error, stackTrace) {
      debugPrint('Supabase 查詢固定接送建議失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<FixedRideSuggestion> _parseSuggestionRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map(
          (row) => FixedRideSuggestion.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  int _timeToMinuteOfDay(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  String _minuteOfDayToTime(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  }
}

class _RideHistoryPoint {
  const _RideHistoryPoint({
    required this.userId,
    required this.destination,
    required this.weekday,
    required this.minuteOfDay,
  });

  final String userId;
  final String destination;
  final int weekday;
  final int minuteOfDay;
}

class _Cluster {
  const _Cluster(this.points);

  final List<_RideHistoryPoint> points;

  int get averageMinuteOfDay {
    final total = points.fold<int>(0, (sum, point) => sum + point.minuteOfDay);
    return (total / points.length).round();
  }
}
