import 'package:supabase_flutter/supabase_flutter.dart';

final class CommunityAnalytics {
  const CommunityAnalytics({
    required this.completionRate,
    required this.medianFulfillmentHours,
    required this.substituteCount,
    required this.topCategories,
    required this.periodDays,
  });

  final double completionRate;
  final double medianFulfillmentHours;
  final int substituteCount;
  final List<({String name, int qty})> topCategories;
  final int periodDays;

  factory CommunityAnalytics.fromJson(Map<String, dynamic> j) {
    final top = j['top_categories'];
    final cats = <({String name, int qty})>[];
    if (top is List) {
      for (final e in top) {
        if (e is Map) {
          cats.add((
            name: e['name']?.toString() ?? '',
            qty: (e['qty'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }
    return CommunityAnalytics(
      completionRate: (j['completion_rate'] as num?)?.toDouble() ?? 0,
      medianFulfillmentHours:
          (j['median_fulfillment_hours'] as num?)?.toDouble() ?? 0,
      substituteCount: (j['substitute_count'] as num?)?.toInt() ?? 0,
      topCategories: cats,
      periodDays: (j['period_days'] as num?)?.toInt() ?? 90,
    );
  }
}

class CommunityAnalyticsRepository {
  CommunityAnalyticsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<CommunityAnalytics> fetch({String? locationPointId, int days = 90}) async {
    try {
      final raw = await _client.rpc(
        'get_community_analytics',
        params: {
          'p_location_point_id': locationPointId,
          'p_days': days,
        },
      );
      if (raw is Map) {
        return CommunityAnalytics.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return const CommunityAnalytics(
      completionRate: 0,
      medianFulfillmentHours: 0,
      substituteCount: 0,
      topCategories: [],
      periodDays: 90,
    );
  }
}
