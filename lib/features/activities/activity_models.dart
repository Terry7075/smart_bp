/// 社區活動（對應 Supabase `community_events`）。
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.createdAt,
    required this.title,
    this.description,
    required this.eventDate,
    this.startTime,
    this.location,
    this.photoUrl,
    this.volunteerId,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String? description;

  /// 活動當天（純日期，00:00），日曆顯示與分群用。
  final DateTime eventDate;

  /// 活動開始時間（自由文字，例如「上午 9:00」），可為空。
  final String? startTime;
  final String? location;

  /// 活動照片公開網址（community-event-photos bucket），可為空。
  final String? photoUrl;
  final String? volunteerId;

  bool get hasPhoto => (photoUrl ?? '').trim().isNotEmpty;

  /// 該活動所屬的「純日期」鍵，方便用 Map 分群。
  DateTime get dayKey => DateTime(eventDate.year, eventDate.month, eventDate.day);

  factory CommunityEvent.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is DateTime
        ? createdRaw.toLocal()
        : DateTime.tryParse(createdRaw?.toString() ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return CommunityEvent(
      id: map['id'].toString(),
      createdAt: createdAt,
      title: (map['title'] as String?)?.trim() ?? '',
      description: _trimOrNull(map['description']),
      eventDate: _parseDate(map['event_date']) ?? createdAt,
      startTime: _trimOrNull(map['start_time']),
      location: _trimOrNull(map['location']),
      photoUrl: _trimOrNull(map['photo_url']),
      volunteerId: map['volunteer_id'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({required String volunteerId}) {
    return {
      'title': title,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'event_date': _formatIsoDate(eventDate),
      if (startTime != null && startTime!.isNotEmpty) 'start_time': startTime,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photo_url': photoUrl,
      'volunteer_id': volunteerId,
    };
  }

  static String? _trimOrNull(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  static String _formatIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 把活動清單依「純日期」分群，方便日曆查詢某天有沒有活動。
Map<DateTime, List<CommunityEvent>> groupEventsByDay(
  List<CommunityEvent> events,
) {
  final map = <DateTime, List<CommunityEvent>>{};
  for (final e in events) {
    map.putIfAbsent(e.dayKey, () => []).add(e);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final t = (a.startTime ?? '').compareTo(b.startTime ?? '');
      if (t != 0) return t;
      return a.createdAt.compareTo(b.createdAt);
    });
  }
  return map;
}
