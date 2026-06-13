class FixedRideSuggestion {
  const FixedRideSuggestion({
    required this.id,
    required this.userId,
    required this.destination,
    required this.weekday,
    required this.suggestedTime,
    required this.occurrenceCount,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    this.elderName,
  });

  final String id;
  final String userId;
  final String destination;
  final int weekday;
  final String suggestedTime;
  final int occurrenceCount;
  final FixedRideSuggestionStatus status;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final String? elderName;

  String get weekdayLabel =>
      const {
        1: '週一',
        2: '週二',
        3: '週三',
        4: '週四',
        5: '週五',
        6: '週六',
        7: '週日',
      }[weekday] ??
      '未知';

  String get displayTime =>
      suggestedTime.length >= 5 ? suggestedTime.substring(0, 5) : suggestedTime;

  factory FixedRideSuggestion.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : null;

    return FixedRideSuggestion(
      id: _stringValue(json['id']),
      userId: _stringValue(json['user_id']),
      destination: _stringValue(json['destination']),
      weekday: _intValue(json['weekday']),
      suggestedTime: _stringValue(json['suggested_time']),
      occurrenceCount: _intValue(json['occurrence_count']),
      status: FixedRideSuggestionStatusX.fromDatabase(
        _stringValue(json['status'], fallback: 'pending'),
      ),
      createdAt:
          _dateTimeValue(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      confirmedAt: _dateTimeValue(json['confirmed_at']),
      elderName:
          profileMap?['name'] as String? ??
          profileMap?['full_name'] as String? ??
          profileMap?['email'] as String?,
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static int _intValue(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

enum FixedRideSuggestionStatus { pending, accepted, rejected }

extension FixedRideSuggestionStatusX on FixedRideSuggestionStatus {
  String get databaseValue => switch (this) {
    FixedRideSuggestionStatus.pending => 'pending',
    FixedRideSuggestionStatus.accepted => 'accepted',
    FixedRideSuggestionStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    FixedRideSuggestionStatus.pending => '待處理',
    FixedRideSuggestionStatus.accepted => '已建立',
    FixedRideSuggestionStatus.rejected => '已略過',
  };

  static FixedRideSuggestionStatus fromDatabase(String value) =>
      switch (value) {
        'accepted' => FixedRideSuggestionStatus.accepted,
        'rejected' => FixedRideSuggestionStatus.rejected,
        _ => FixedRideSuggestionStatus.pending,
      };
}

class FixedRidePattern {
  const FixedRidePattern({
    required this.userId,
    required this.destination,
    required this.weekday,
    required this.suggestedTime,
    required this.occurrenceCount,
  });

  final String userId;
  final String destination;
  final int weekday;
  final String suggestedTime;
  final int occurrenceCount;
}
