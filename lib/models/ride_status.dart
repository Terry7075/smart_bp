enum RideStatus {
  pending,
  matched,
  pickedUp,
  onTheWay,
  completed,
  cancelled,
}

extension RideStatusX on RideStatus {
  String get databaseValue => switch (this) {
        RideStatus.pending => 'pending',
        RideStatus.matched => 'matched',
        RideStatus.pickedUp => 'picked_up',
        RideStatus.onTheWay => 'on_the_way',
        RideStatus.completed => 'completed',
        RideStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        RideStatus.pending => '等待媒合',
        RideStatus.matched => '已媒合司機',
        RideStatus.pickedUp => '已接到人',
        RideStatus.onTheWay => '路途中',
        RideStatus.completed => '已送達',
        RideStatus.cancelled => '已取消',
      };

  static RideStatus fromDatabase(String value) => switch (value) {
        'pending' => RideStatus.pending,
        'matched' => RideStatus.matched,
        'picked_up' => RideStatus.pickedUp,
        'on_the_way' => RideStatus.onTheWay,
        'completed' => RideStatus.completed,
        'cancelled' => RideStatus.cancelled,
        _ => throw ArgumentError('Unknown ride status: $value'),
      };
}
