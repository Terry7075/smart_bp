import 'standing_ride_weekdays.dart';

class DriverStandingRideOffer {
  const DriverStandingRideOffer({
    required this.id,
    required this.driverId,
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
    this.customDestination,
    this.returnTime,
    this.note,
    this.endDate,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.bookedBy,
    this.bookedAt,
    this.standingRideRequestId,
  });

  final String id;
  final String driverId;
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
  final DriverStandingRideOfferStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? bookedBy;
  final DateTime? bookedAt;
  final String? standingRideRequestId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayDestination =>
      customDestination?.trim().isNotEmpty == true ? customDestination! : destination;
  String get serviceWeekdaysLabel => formatServiceWeekdays(serviceWeekdays);

  factory DriverStandingRideOffer.fromJson(Map<String, dynamic> json) {
    return DriverStandingRideOffer(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
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
      status: DriverStandingRideOfferStatusX.fromDatabase(
        json['status'] as String,
      ),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      bookedBy: json['booked_by'] as String?,
      bookedAt: json['booked_at'] == null
          ? null
          : DateTime.parse(json['booked_at'] as String),
      standingRideRequestId: json['standing_ride_request_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

enum DriverStandingRideOfferStatus {
  pending,
  approved,
  rejected,
  booked,
  cancelled,
}

extension DriverStandingRideOfferStatusX on DriverStandingRideOfferStatus {
  String get databaseValue => switch (this) {
        DriverStandingRideOfferStatus.pending => 'pending',
        DriverStandingRideOfferStatus.approved => 'approved',
        DriverStandingRideOfferStatus.rejected => 'rejected',
        DriverStandingRideOfferStatus.booked => 'booked',
        DriverStandingRideOfferStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        DriverStandingRideOfferStatus.pending => '待審核',
        DriverStandingRideOfferStatus.approved => '可選擇',
        DriverStandingRideOfferStatus.rejected => '未通過',
        DriverStandingRideOfferStatus.booked => '已配對',
        DriverStandingRideOfferStatus.cancelled => '已取消',
      };

  static DriverStandingRideOfferStatus fromDatabase(String value) =>
      switch (value) {
        'pending' => DriverStandingRideOfferStatus.pending,
        'approved' => DriverStandingRideOfferStatus.approved,
        'rejected' => DriverStandingRideOfferStatus.rejected,
        'booked' => DriverStandingRideOfferStatus.booked,
        'cancelled' => DriverStandingRideOfferStatus.cancelled,
        _ => throw ArgumentError(
            'Unknown driver standing ride offer status: $value'),
      };
}
