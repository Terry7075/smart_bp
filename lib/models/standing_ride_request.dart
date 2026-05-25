import 'standing_ride_weekdays.dart';

class StandingRideRequest {
  const StandingRideRequest({
    required this.id,
    required this.elderId,
    required this.pickupLocation,
    required this.destination,
    required this.rideTime,
    required this.passengerCount,
    required this.needReturn,
    required this.serviceWeekdays,
    required this.startDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.driverId,
    this.driverStandingRideOfferId,
    this.customDestination,
    this.returnTime,
    this.note,
    this.endDate,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String elderId;
  final String? driverId;
  final String? driverStandingRideOfferId;
  final String pickupLocation;
  final String destination;
  final String? customDestination;
  final String rideTime;
  final int passengerCount;
  final bool needReturn;
  final String? returnTime;
  final String? note;
  final List<int> serviceWeekdays;
  final DateTime startDate;
  final DateTime? endDate;
  final StandingRideStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayDestination => customDestination?.trim().isNotEmpty == true
      ? customDestination!
      : destination;
  String get serviceWeekdaysLabel => formatServiceWeekdays(serviceWeekdays);

  factory StandingRideRequest.fromJson(Map<String, dynamic> json) {
    return StandingRideRequest(
      id: json['id'] as String,
      elderId: json['elder_id'] as String,
      driverId: json['driver_id'] as String?,
      driverStandingRideOfferId:
          json['driver_standing_ride_offer_id'] as String?,
      pickupLocation: json['pickup_location'] as String,
      destination: json['destination'] as String,
      customDestination: json['custom_destination'] as String?,
      rideTime: json['ride_time'] as String,
      passengerCount: json['passenger_count'] as int,
      needReturn: json['need_return'] as bool,
      returnTime: json['return_time'] as String?,
      note: json['note'] as String?,
      serviceWeekdays: parseServiceWeekdays(json['service_weekdays']),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      status: StandingRideStatusX.fromDatabase(json['status'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

enum StandingRideStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension StandingRideStatusX on StandingRideStatus {
  String get databaseValue => switch (this) {
        StandingRideStatus.pending => 'pending',
        StandingRideStatus.approved => 'approved',
        StandingRideStatus.rejected => 'rejected',
        StandingRideStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        StandingRideStatus.pending => '待審核',
        StandingRideStatus.approved => '已核准',
        StandingRideStatus.rejected => '未通過',
        StandingRideStatus.cancelled => '已取消',
      };

  static StandingRideStatus fromDatabase(String value) => switch (value) {
        'pending' => StandingRideStatus.pending,
        'approved' => StandingRideStatus.approved,
        'rejected' => StandingRideStatus.rejected,
        'cancelled' => StandingRideStatus.cancelled,
        _ => throw ArgumentError('Unknown standing ride status: $value'),
      };
}
