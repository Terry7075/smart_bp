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

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

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
      );
}
