class DriverLocation {
  const DriverLocation({
    required this.id,
    required this.rideMatchId,
    required this.rideRequestId,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.accuracyMeters,
    this.heading,
    this.speedMps,
  });

  final String id;
  final String rideMatchId;
  final String rideRequestId;
  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final double? accuracyMeters;
  final double? heading;
  final double? speedMps;

  factory DriverLocation.fromJson(Map<String, dynamic> json) => DriverLocation(
        id: json['id'] as String,
        rideMatchId: json['ride_match_id'] as String,
        rideRequestId: json['ride_request_id'] as String,
        driverId: json['driver_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        speedMps: (json['speed_mps'] as num?)?.toDouble(),
      );
}
