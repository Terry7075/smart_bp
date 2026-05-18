import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/ride_feedback.dart';

void main() {
  test('RideFeedback distinguishes issue reports from ratings', () {
    final issue = RideFeedback.fromJson({
      'id': 'feedback-id',
      'ride_request_id': 'ride-id',
      'ride_match_id': null,
      'reporter_id': 'user-id',
      'reporter_role': 'elder',
      'rating': null,
      'comment': null,
      'issue_type': 'user_report',
      'issue_description': '司機遲到',
      'is_resolved': false,
      'created_at': '2026-05-16T01:00:00Z',
    });

    expect(issue.isIssue, isTrue);
    expect(issue.issueDescription, '司機遲到');
  });
}
