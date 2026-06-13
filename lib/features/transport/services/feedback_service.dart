import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/ride_feedback.dart';

class FeedbackService {
  FeedbackService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<RideFeedback> submitFeedback({
    required String rideRequestId,
    int? rating,
    String? comment,
    String? issueType,
    String? issueDescription,
  }) async {
    final row = await _client.rpc('submit_ride_feedback', params: {
      'p_ride_request_id': rideRequestId,
      'p_rating': rating,
      'p_comment': comment,
      'p_issue_type': issueType,
      'p_issue_description': issueDescription,
    });
    return RideFeedback.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<RideFeedback> resolveFeedback(String feedbackId) async {
    final row = await _client.rpc('resolve_ride_feedback', params: {
      'p_feedback_id': feedbackId,
    });
    return RideFeedback.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Stream<List<RideFeedback>> watchFeedbackForRide(String rideRequestId) {
    return _client
        .from('ride_feedback')
        .stream(primaryKey: ['id'])
        .eq('ride_request_id', rideRequestId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => RideFeedback.fromJson(Map<String, dynamic>.from(row)))
            .toList());
  }

  Stream<List<RideFeedback>> watchUnresolvedIssues() {
    return _client
        .from('ride_feedback')
        .stream(primaryKey: ['id'])
        .eq('is_resolved', false)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => RideFeedback.fromJson(Map<String, dynamic>.from(row)))
            .where((feedback) => feedback.isIssue)
            .toList());
  }
}
