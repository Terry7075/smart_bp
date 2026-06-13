import 'package:smart_bp/features/activities/activity_models.dart';

/// 社區固定採購日：每週四志工統一至全聯採買。
abstract final class CommunityProcurementDay {
  static const title = '社區統一採購日';
  static const int weekday = DateTime.thursday;

  static bool isProcurementDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.weekday == weekday;
  }

  static DateTime nextProcurementDay([DateTime? from]) {
    final base = from ?? DateTime.now();
    var d = DateTime(base.year, base.month, base.day);
    if (d.weekday == weekday) return d;
    var guard = 0;
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
      guard++;
      if (guard > 7) break;
    }
    return d;
  }

  static String _weekdayLabel(DateTime day) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return labels[day.weekday - 1];
  }

  static String nextProcurementShort([DateTime? from]) {
    final next = nextProcurementDay(from);
    return '${next.month}/${next.day}（週${_weekdayLabel(next)}）';
  }

  /// 志工接單後推播給長輩的內文。
  static String elderAcceptNotice() {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (isProcurementDay(t)) {
      return '志工已接單，今天為社區統一採購日，將盡快為您採買';
    }
    return '志工已接單，將於下次採購日（$nextProcurementShort(t)）為您採買';
  }

  /// 志工完成採購後推播給長輩的內文。
  static const elderCompleteNotice = '物資已經送到活動中心囉，歡迎來領取';

  /// 志工端彙整清單標題（依下次採購日）。
  static String volunteerAggregateListTitle([DateTime? from]) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (isProcurementDay(t)) {
      return '本日代購總清單';
    }
    return '${nextProcurementShort(t)}代購總清單';
  }

  static String homeLine([DateTime? from]) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (isProcurementDay(t)) {
      return '今天是社區統一採購日，志工代買後送回活動中心';
    }
    final next = nextProcurementDay(t);
    return '下次採購日：${next.month}/${next.day}（週${_weekdayLabel(next)}）';
  }

  static String flowBannerText([DateTime? from]) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    if (isProcurementDay(t)) {
      return '今天是社區統一採購日，請確認需求已送出給志工';
    }
    final next = nextProcurementDay(t);
    return '下次採購日：${next.month}/${next.day}（週${_weekdayLabel(next)}），請在此之前送出需求';
  }

  /// 全聯賣場走道示意圖（採購日活動卡背景）。
  static const photoUrl =
      'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1200&q=80';

  static CommunityEvent eventFor(DateTime thursday) {
    final day = DateTime(thursday.year, thursday.month, thursday.day);
    return CommunityEvent(
      id: 'procurement-${day.year}-${day.month}-${day.day}',
      createdAt: day,
      title: title,
      description: '志工統一至全聯採買日用品，完成後送回社區活動中心。'
          '請於週四前在柑仔店填寫並送出需求。',
      eventDate: day,
      startTime: '統一採購',
      location: '全聯 → 社區活動中心',
      photoUrl: photoUrl,
    );
  }

  /// 將當月每週四的虛擬採購日活動併入日曆清單。
  static List<CommunityEvent> mergeEvents(
    List<CommunityEvent> fromDb, {
    required int year,
    required int month,
  }) {
    final result = List<CommunityEvent>.from(fromDb);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      if (d.weekday != weekday) continue;
      final virtual = eventFor(d);
      final exists = result.any(
        (e) =>
            e.id == virtual.id ||
            (e.dayKey == d && e.title.contains('採購')),
      );
      if (!exists) result.add(virtual);
    }
    result.sort((a, b) {
      final byDate = a.eventDate.compareTo(b.eventDate);
      if (byDate != 0) return byDate;
      return a.createdAt.compareTo(b.createdAt);
    });
    return result;
  }

  static CommunityEvent nearestUpcomingEvent([DateTime? from]) =>
      eventFor(nextProcurementDay(from));

  static bool isVirtualEvent(CommunityEvent event) =>
      event.id.startsWith('procurement-');
}
