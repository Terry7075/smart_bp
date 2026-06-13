class Driver {
  const Driver({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.address,
    required this.carPlate,
    required this.maxPassengers,
    required this.approvalStatus,
    this.carModel,
    this.status = 'offline',
    this.remainingSeats,
    this.currentLatitude,
    this.currentLongitude,
    this.availableDestination,
    this.availableRideDate,
    this.availableRideTime,
  });

  final String id;
  final String userId;
  final String name;
  final String phone;
  final String address;
  final String carPlate;
  final String? carModel;
  final int maxPassengers;
  final String approvalStatus;
  final String status;
  final int? remainingSeats;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? availableDestination;
  final DateTime? availableRideDate;
  final String? availableRideTime;

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';
  bool get isOnline => status == 'online';
  int get effectiveRemainingSeats => remainingSeats ?? maxPassengers;

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String,
    carPlate: json['car_plate'] as String,
    carModel: json['car_model'] as String?,
    maxPassengers: json['max_passengers'] as int,
    approvalStatus: json['approval_status'] as String,
    status: json['status'] as String? ?? 'offline',
    remainingSeats: json['remaining_seats'] as int?,
    currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
    currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
    availableDestination: json['available_destination'] as String?,
    availableRideDate: json['available_ride_date'] == null
        ? null
        : DateTime.parse(json['available_ride_date'] as String),
    availableRideTime: json['available_ride_time'] as String?,
  );
}
