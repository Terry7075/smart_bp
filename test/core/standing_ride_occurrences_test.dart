import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bp/features/transport/core/utils/standing_ride_occurrences.dart';

void main() {
  group('generateStandingRideDates', () {
    test('generates dates only for selected weekdays', () {
      final dates = generateStandingRideDates(
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        startDate: DateTime(2026, 5, 25),
        endDate: null,
        today: DateTime(2026, 5, 25),
        windowDays: 7,
      );

      expect(dates, [
        DateTime(2026, 5, 25),
        DateTime(2026, 5, 27),
        DateTime(2026, 5, 29),
      ]);
    });

    test('stops at end date before the generation window ends', () {
      final dates = generateStandingRideDates(
        weekdays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
        startDate: DateTime(2026, 5, 22),
        endDate: DateTime(2026, 5, 24),
        today: DateTime(2026, 5, 22),
      );

      expect(
        dates,
        [
          DateTime(2026, 5, 22),
          DateTime(2026, 5, 23),
          DateTime(2026, 5, 24),
        ],
      );
    });

    test('returns no dates when selected weekdays do not occur in range', () {
      final dates = generateStandingRideDates(
        weekdays: {DateTime.monday},
        startDate: DateTime(2026, 5, 23),
        endDate: DateTime(2026, 5, 24),
        today: DateTime(2026, 5, 23),
      );

      expect(dates, isEmpty);
    });
  });
}
