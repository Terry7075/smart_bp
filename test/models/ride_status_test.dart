import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/transport/models/ride_status.dart';

void main() {
  group('RideStatusX', () {
    test('maps statuses to elder-friendly labels', () {
      expect(RideStatus.pending.label, '等待媒合');
      expect(RideStatus.matched.label, '已媒合司機');
      expect(RideStatus.pickedUp.label, '已接到人');
      expect(RideStatus.onTheWay.label, '路途中');
      expect(RideStatus.completed.label, '已送達');
      expect(RideStatus.cancelled.label, '已取消');
    });

    test('parses database values', () {
      expect(RideStatusX.fromDatabase('picked_up'), RideStatus.pickedUp);
      expect(RideStatusX.fromDatabase('on_the_way'), RideStatus.onTheWay);
    });
  });
}
