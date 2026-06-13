import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/activities/activity_models.dart';
import 'package:smart_bp/features/activities/activity_provider.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';

const Color _kElderGreen = Color(0xFF2E7D32);
const Color _kDotGreen = Color(0xFF43A047);
const Color _kProcurementOrange = Color(0xFFE65100);

/// 長輩端：社區活動日曆。有活動的日子顯示綠點，點該日看當天活動。
class ElderActivitiesPage extends ConsumerStatefulWidget {
  const ElderActivitiesPage({super.key});

  @override
  ConsumerState<ElderActivitiesPage> createState() =>
      _ElderActivitiesPageState();
}

class _ElderActivitiesPageState extends ConsumerState<ElderActivitiesPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _goPrevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvents = ref.watch(communityEventsProvider);

    return asyncEvents.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _kElderGreen, strokeWidth: 6),
      ),
      error: (e, _) => _ErrorView(
        message: communityEventFriendlyError(e),
        onRetry: () => ref.read(communityEventsProvider.notifier).refresh(),
      ),
      data: (events) {
        final merged = CommunityProcurementDay.mergeEvents(
          events,
          year: _visibleMonth.year,
          month: _visibleMonth.month,
        );
        final byDay = groupEventsByDay(merged);
        final selectedEvents = byDay[_dayKey(_selectedDay)] ?? const [];

        return RefreshIndicator(
          color: _kElderGreen,
          onRefresh: () =>
              ref.read(communityEventsProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _MonthCalendar(
                visibleMonth: _visibleMonth,
                selectedDay: _selectedDay,
                eventsByDay: byDay,
                onPrevMonth: _goPrevMonth,
                onNextMonth: _goNextMonth,
                onSelectDay: (d) => setState(() => _selectedDay = d),
              ),
              const SizedBox(height: 24),
              _SelectedDayHeader(day: _selectedDay, count: selectedEvents.length),
              const SizedBox(height: 12),
              if (selectedEvents.isEmpty)
                const _NoEventsForDay()
              else
                for (final ev in selectedEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _EventCard(event: ev),
                  ),
            ],
          ),
        );
      },
    );
  }
}

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

// ============================================================================
//  月曆
// ============================================================================

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.selectedDay,
    required this.eventsByDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  final DateTime visibleMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<CommunityEvent>> eventsByDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    // weekday: Mon=1..Sun=7 → 我們的格子從週日開始，所以週日=0。
    final leadingBlanks = firstOfMonth.weekday % 7;
    final today = _dayKey(DateTime.now());

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, day);
      final dayEvents = eventsByDay[date] ?? const [];
      final hasEvents = dayEvents.isNotEmpty;
      final hasProcurement = dayEvents.any(CommunityProcurementDay.isVirtualEvent);
      final isSelected = _dayKey(selectedDay) == date;
      final isToday = today == date;
      cells.add(
        _DayCell(
          day: day,
          hasEvents: hasEvents,
          hasProcurement: hasProcurement,
          isSelected: isSelected,
          isToday: isToday,
          onTap: () => onSelectDay(date),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              _ArrowButton(icon: Icons.chevron_left, onTap: onPrevMonth),
              Expanded(
                child: Text(
                  '${visibleMonth.year} 年 ${visibleMonth.month} 月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _kElderGreen,
                  ),
                ),
              ),
              _ArrowButton(icon: Icons.chevron_right, onTap: onNextMonth),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _weekdayLabels.length; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: (i == 0 || i == 6)
                            ? const Color(0xFFC62828)
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kElderGreen.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 30, color: _kElderGreen),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasEvents,
    required this.hasProcurement,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool hasEvents;
  final bool hasProcurement;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = isSelected
        ? _kElderGreen
        : isToday
            ? _kElderGreen.withValues(alpha: 0.12)
            : Colors.transparent;
    final Color fg = isSelected ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasEvents
                  ? (isSelected
                      ? Colors.white
                      : (hasProcurement ? _kProcurementOrange : _kDotGreen))
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  選定日期區塊
// ============================================================================

class _SelectedDayHeader extends StatelessWidget {
  const _SelectedDayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final w = _weekdays[(day.weekday - 1) % 7];
    return Row(
      children: [
        const Icon(Icons.event_note, size: 28, color: _kElderGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${day.month} 月 ${day.day} 日（週$w）',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _kElderGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count 個活動',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kElderGreen,
              ),
            ),
          ),
      ],
    );
  }
}

class _NoEventsForDay extends StatelessWidget {
  const _NoEventsForDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        children: [
          Icon(Icons.free_breakfast_outlined, size: 56, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            '這天沒有安排活動',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    final isProcurement = CommunityProcurementDay.isVirtualEvent(event);
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProcurement)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _kProcurementOrange.withValues(alpha: 0.12),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_basket_outlined,
                        color: _kProcurementOrange, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '每週四固定採購',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kProcurementOrange,
                      ),
                    ),
                  ],
                ),
              ),
            if (event.hasPhoto)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  event.photoUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const ColoredBox(
                      color: Color(0xFFF0F0F0),
                      child: Center(
                        child: CircularProgressIndicator(color: _kElderGreen),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF0F0F0),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: Colors.black26),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  if (event.startTime != null) ...[
                    const SizedBox(height: 10),
                    _IconLine(icon: Icons.schedule, text: event.startTime!),
                  ],
                  if (event.location != null) ...[
                    const SizedBox(height: 8),
                    _IconLine(
                        icon: Icons.location_on_outlined, text: event.location!),
                  ],
                  if (event.description != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      event.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EventDetailSheet(event: event),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: _kElderGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event});

  final CommunityEvent event;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (event.hasPhoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                event.photoUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          _IconLine(
            icon: Icons.calendar_today,
            text: '${event.eventDate.year} 年 '
                '${event.eventDate.month} 月 ${event.eventDate.day} 日',
          ),
          if (event.startTime != null) ...[
            const SizedBox(height: 12),
            _IconLine(icon: Icons.schedule, text: event.startTime!),
          ],
          if (event.location != null) ...[
            const SizedBox(height: 12),
            _IconLine(icon: Icons.location_on_outlined, text: event.location!),
          ],
          if (event.description != null) ...[
            const SizedBox(height: 20),
            Text(
              event.description!,
              style: const TextStyle(fontSize: 20, height: 1.6),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: _kElderGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '我知道了',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 72, color: Color(0xFFBF360C)),
        const SizedBox(height: 16),
        Text(
          '讀取活動失敗：\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBF360C),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 28),
          label: const Text(
            '重新讀取',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _kElderGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
