import 'ride_status.dart';

class RideMatch {
  const RideMatch({
    required this.id,
    required this.rideRequestId,
    required this.driverId,
    required this.matchType,
    required this.status,
    this.matchedBy,
  });

  final String id;
  final String rideRequestId;
  final String driverId;
  final String? matchedBy;
  final String matchType;
  final RideStatus status;

  factory RideMatch.fromJson(Map<String, dynamic> json) => RideMatch(
        id: json['id'] as String,
        rideRequestId: json['ride_request_id'] as String,
        driverId: json['driver_id'] as String,
        matchedBy: json['matched_by'] as String?,
        matchType: json['match_type'] as String,
        status: RideStatusX.fromDatabase(json['status'] as String),
      );
}
