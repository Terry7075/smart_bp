class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedRideRequestId,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? relatedRideRequestId;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        isRead: json['is_read'] as bool,
        relatedRideRequestId: json['related_ride_request_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
