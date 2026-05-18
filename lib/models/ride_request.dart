import 'ride_status.dart';

class RideRequest {
  const RideRequest({
    required this.id,
    required this.elderId,
    required this.pickupLocation,
    required this.destination,
    required this.rideDate,
    required this.rideTime,
    required this.passengerCount,
    required this.needReturn,
    required this.status,
    this.customDestination,
    this.returnTime,
    this.note,
    this.distanceKm,
    this.estimatedPrice,
  });

  final String id;
  final String elderId;
  final String pickupLocation;
  final String destination;
  final String? customDestination;
  final DateTime rideDate;
  final String rideTime;
  final int passengerCount;
  final bool needReturn;
  final String? returnTime;
  final String? note;
  final num? distanceKm;
  final int? estimatedPrice;
  final RideStatus status;

  String get displayDestination =>
      destination == '自行輸入地點' ? (customDestination ?? destination) : destination;

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
        id: json['id'] as String,
        elderId: json['elder_id'] as String,
        pickupLocation: json['pickup_location'] as String,
        destination: json['destination'] as String,
        customDestination: json['custom_destination'] as String?,
        rideDate: DateTime.parse(json['ride_date'] as String),
        rideTime: json['ride_time'] as String,
        passengerCount: json['passenger_count'] as int,
        needReturn: json['need_return'] as bool,
        returnTime: json['return_time'] as String?,
        note: json['note'] as String?,
        distanceKm: json['distance_km'] as num?,
        estimatedPrice: json['estimated_price'] as int?,
        status: RideStatusX.fromDatabase(json['status'] as String),
      );
}
