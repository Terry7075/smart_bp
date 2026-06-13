import '../../models/standing_ride_weekdays.dart';

List<DateTime> generateStandingRideDates({
  required Set<int> weekdays,
  required DateTime startDate,
  required DateTime? endDate,
  DateTime? today,
  int windowDays = 30,
}) {
  final normalizedWeekdays = normalizeServiceWeekdays(weekdays).toSet();
  final normalizedToday = _dateOnly(today ?? DateTime.now());
  final firstDate = _maxDate(_dateOnly(startDate), normalizedToday);
  final windowEnd = normalizedToday.add(Duration(days: windowDays - 1));
  final lastDate =
      endDate == null ? windowEnd : _minDate(_dateOnly(endDate), windowEnd);
  if (lastDate.isBefore(firstDate)) return const [];

  final dates = <DateTime>[];
  for (var date = firstDate;
      !date.isAfter(lastDate);
      date = date.add(const Duration(days: 1))) {
    if (normalizedWeekdays.contains(date.weekday)) {
      dates.add(date);
    }
  }
  return dates;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
