const isoWeekdays = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

const _weekdayLabels = <int, String>{
  DateTime.monday: '週一',
  DateTime.tuesday: '週二',
  DateTime.wednesday: '週三',
  DateTime.thursday: '週四',
  DateTime.friday: '週五',
  DateTime.saturday: '週六',
  DateTime.sunday: '週日',
};

List<int> normalizeServiceWeekdays(Iterable<int> weekdays) {
  final values = weekdays.toList();
  if (values.isEmpty) {
    throw ArgumentError('At least one weekday is required.');
  }
  final unique = values.toSet();
  if (unique.length != values.length) {
    throw ArgumentError('Weekdays must not contain duplicates.');
  }
  if (unique
      .any((weekday) => weekday < DateTime.monday || weekday > DateTime.sunday)) {
    throw ArgumentError('Weekdays must be ISO weekday values from 1 to 7.');
  }
  return unique.toList()..sort();
}

String formatServiceWeekdays(Iterable<int> weekdays) {
  return normalizeServiceWeekdays(weekdays)
      .map((weekday) => _weekdayLabels[weekday]!)
      .join('、');
}

List<int> parseServiceWeekdays(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return normalizeServiceWeekdays(value.map((item) => (item as num).toInt()));
  }
  throw ArgumentError('Unsupported weekdays value: $value');
}
