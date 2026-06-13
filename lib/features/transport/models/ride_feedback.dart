class RideFeedback {
  const RideFeedback({
    required this.id,
    required this.rideRequestId,
    required this.reporterId,
    required this.reporterRole,
    required this.isResolved,
    required this.createdAt,
    this.rideMatchId,
    this.rating,
    this.comment,
    this.issueType,
    this.issueDescription,
  });

  final String id;
  final String rideRequestId;
  final String? rideMatchId;
  final String reporterId;
  final String reporterRole;
  final int? rating;
  final String? comment;
  final String? issueType;
  final String? issueDescription;
  final bool isResolved;
  final DateTime createdAt;

  bool get isIssue => issueType != null && issueType!.isNotEmpty;

  factory RideFeedback.fromJson(Map<String, dynamic> json) => RideFeedback(
        id: json['id'] as String,
        rideRequestId: json['ride_request_id'] as String,
        rideMatchId: json['ride_match_id'] as String?,
        reporterId: json['reporter_id'] as String,
        reporterRole: json['reporter_role'] as String,
        rating: json['rating'] as int?,
        comment: json['comment'] as String?,
        issueType: json['issue_type'] as String?,
        issueDescription: json['issue_description'] as String?,
        isResolved: json['is_resolved'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
