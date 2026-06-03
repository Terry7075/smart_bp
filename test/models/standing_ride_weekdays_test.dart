import 'package:flutter_test/flutter_test.dart';
import 'package:mingde_transport/models/standing_ride_weekdays.dart';

void main() {
  group('service weekdays', () {
    test('formats selected ISO weekdays in week order', () {
      expect(formatServiceWeekdays([5, 1, 3]), '週一、週三、週五');
    });

    test('rejects empty weekdays', () {
      expect(() => normalizeServiceWeekdays([]), throwsArgumentError);
    });

    test('rejects weekdays outside ISO range', () {
      expect(() => normalizeServiceWeekdays([1, 8]), throwsArgumentError);
    });

    test('rejects duplicated weekdays', () {
      expect(() => normalizeServiceWeekdays([1, 1]), throwsArgumentError);
    });
  });
}
