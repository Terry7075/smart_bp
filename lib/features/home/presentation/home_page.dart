// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/activities/activity_models.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';
import 'package:smart_bp/features/activities/activity_provider.dart';
import 'package:smart_bp/features/activities/elder_activities_page.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/family/data/family_links_repository.dart';
import 'package:smart_bp/features/family/presentation/family_providers.dart';
import 'package:smart_bp/features/health/presentation/health_page.dart';
import 'package:smart_bp/features/health_monitoring/health_monitoring_provider.dart';
import 'package:smart_bp/features/health_monitoring/presentation/elder_monitoring_tab.dart';
import 'package:smart_bp/features/home/presentation/notification_center_page.dart';
import 'package:smart_bp/features/prescription/elder_prescription_sync.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';

/// 首頁底部導覽目前選中的索引（預設 0 = 首頁）。
final homeBottomNavIndexProvider = NotifierProvider<HomeBottomNavIndex, int>(
  HomeBottomNavIndex.new,
);

class HomeBottomNavIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    state = index;
  }
}

/// 明德 e 達人 — 首頁（長輩友善大字體、高對比）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialTab = 0});

  /// 由路由 `?tab=` 或小幫手帶路指定底部導覽索引（0–5）。
  final int initialTab;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<String> _bottomNavLabels = [
    '首頁',
    '柑仔店',
    '交通',
    '健康',
    '監測',
    '活動',
  ];

  String? _lastSnackTaskId;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab;
    if (tab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(homeBottomNavIndexProvider.notifier).select(tab);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navIndex = ref.watch(homeBottomNavIndexProvider);

    // 常駐：比對 volunteer_tasks ↔ prescriptions，補同步 + 排提醒。
    ref.watch(elderPrescriptionSyncProvider);

    // 常駐：監聽 notification_outbox，收到 health_alert 時顯示本機通知。
    ref.watch(outboxDispatcherProvider);

    ref.listen<VolunteerTask?>(elderVolunteerConfirmSnackProvider, (_, next) {
      if (next == null) return;
      if (_lastSnackTaskId == next.id) return;
      _lastSnackTaskId = next.id;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 6),
          content: Text(
            '📢 志工已完成確認，並幫您設好吃藥提醒囉！',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
      ref.read(elderVolunteerConfirmSnackProvider.notifier).clear();
    });

    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: _buildScaffold(context, ref, colorScheme, navIndex),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    int navIndex,
  ) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '明德e達人',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        actions: [
          const _NotificationBellButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<_AvatarMenu>(
              tooltip: '個人選單',
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                switch (value) {
                  case _AvatarMenu.profile:
                    context.push('/profile');
                  case _AvatarMenu.logout:
                    ref.read(authProvider.notifier).signOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_AvatarMenu>(
                  value: _AvatarMenu.profile,
                  height: 56,
                  child: Text(
                    '個人資料',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuItem<_AvatarMenu>(
                  value: _AvatarMenu.logout,
                  height: 56,
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 24),
                      SizedBox(width: 12),
                      Text(
                        '登出',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: const _UserAvatar(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: navIndex == 3
            ? const HealthPage()
            : navIndex == 4
                ? const ElderMonitoringTab()
                : navIndex == 5
                    ? const ElderActivitiesPage()
                    : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _GreetingCard(),
                        const SizedBox(height: 12),
                        const _FamilyRequestBanner(),
                        const SizedBox(height: 8),
                        const _ActionGrid(),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navIndex,
        onTap: (index) {
          if (index == 1) {
            context.push('/shop');
            return;
          }
          ref.read(homeBottomNavIndexProvider.notifier).select(index);
        },
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        selectedFontSize: 20,
        unselectedFontSize: 20,
        iconSize: 28,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: '柑仔店',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_outlined),
            activeIcon: Icon(Icons.directions_bus),
            label: '交通',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '健康',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            activeIcon: Icon(Icons.monitor_heart),
            label: '監測',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: '活動',
          ),
        ],
      ),
    );
  }
}

enum _AvatarMenu { profile, logout }

/// 長者首頁：待確認的家屬綁定請求（同意才開放家屬查看代購進度）。
///
/// 只有在有 pending 請求時才顯示;沒有請求 / 載入中 / 出錯都收起,不干擾首頁。
class _FamilyRequestBanner extends ConsumerWidget {
  const _FamilyRequestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingFamilyRequestsProvider);
    final list = pending.asData?.value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final FamilyElderLink link in list)
          Card(
            color: const Color(0xFFFFF3E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFFFB74D)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.family_restroom,
                          color: Color(0xFFE65100), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '有家屬想綁定您的帳號（稱謂：${link.relation}），'
                          '同意後對方才能查看您的代購進度。',
                          style: const TextStyle(fontSize: 18, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _respond(context, ref, link, true),
                          icon: const Icon(Icons.check, size: 24),
                          label: const Text('同意',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBF360C),
                            side: const BorderSide(color: Color(0xFFBF360C)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _respond(context, ref, link, false),
                          icon: const Icon(Icons.close, size: 24),
                          label: const Text('拒絕',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    FamilyElderLink link,
    bool approve,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(familyLinksRepositoryProvider);
    try {
      if (approve) {
        await repo.approveLink(link.id);
      } else {
        await repo.rejectLink(link.id);
      }
      ref.invalidate(pendingFamilyRequestsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(approve ? '已同意家屬綁定' : '已拒絕綁定請求')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    }
  }
}

/// AppBar 通知小鈴鐺：有待審核藥單時顯示紅點。
class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(elderPrescriptionSyncProvider);
    final badgeCount = ref.watch(elderNotificationBadgeCountProvider);

    return IconButton(
      onPressed: () => _openNotificationCenter(context),
      tooltip: '系統通知',
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text(
          badgeCount > 9 ? '9+' : '$badgeCount',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFC62828),
        child: const Icon(Icons.notifications_outlined, size: 28),
      ),
    );
  }

  void _openNotificationCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationCenterPage(),
      ),
    );
  }
}

class _UserAvatar extends ConsumerWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final char = ref.watch(profileProvider).maybeWhen(
          data: (p) => p?.firstChar ?? '長',
          orElse: () => '長',
        );

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: onPrimary,
        ),
      ),
    );
  }
}

class _GreetingCard extends ConsumerWidget {
  const _GreetingCard();

  static const _orangeChat = Color(0xFFE65100);
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  /// 將姓名加上適當稱謂：兩字以上 → 「○○ 您好」；單字 → 直接稱呼。
  /// 取不到名字時 fallback 為「長輩」，避免顯示空字串。
  String _addressFromName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '長輩';
    return trimmed;
  }

  DateTime _todayKey() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _upcomingEventLine(List<CommunityEvent> events) {
    final today = _todayKey();
    final procurementLine = CommunityProcurementDay.homeLine(today);
    final upcoming = events.where((e) => !e.dayKey.isBefore(today)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    if (upcoming.isEmpty) return procurementLine;
    final e = upcoming.first;
    final nextProcurement = CommunityProcurementDay.nextProcurementDay(today);
    if (!nextProcurement.isBefore(e.eventDate)) {
      return procurementLine;
    }
    final w = _weekdays[e.eventDate.weekday - 1];
    return '近期活動：${e.title}（${e.eventDate.month}/${e.eventDate.day} 週$w）';
  }

  List<CommunityEvent> _collectUpcomingEvents(List<CommunityEvent> events) {
    final today = _todayKey();
    var merged = List<CommunityEvent>.from(events);
    for (var offset = 0; offset < 3; offset++) {
      final month = DateTime(today.year, today.month + offset, 1);
      merged = CommunityProcurementDay.mergeEvents(
        merged,
        year: month.year,
        month: month.month,
      );
    }
    final upcoming = merged.where((e) => !e.dayKey.isBefore(today)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final seen = <String>{};
    final unique = <CommunityEvent>[];
    for (final e in upcoming) {
      if (seen.add(e.id)) unique.add(e);
    }
    return unique;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final asyncProfile = ref.watch(profileProvider);
    final asyncEvents = ref.watch(communityEventsProvider);

    final greeting = greetingForNow();
    final addressee = asyncProfile.maybeWhen(
      data: (p) => _addressFromName(p?.name),
      orElse: () => '長輩',
    );
    final eventLine = asyncEvents.maybeWhen(
      data: _upcomingEventLine,
      orElse: () => CommunityProcurementDay.homeLine(),
    );
    final upcomingEvents = asyncEvents.maybeWhen(
      data: _collectUpcomingEvents,
      orElse: () => [CommunityProcurementDay.nearestUpcomingEvent()],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 108),
                child: Text(
                  '$greeting，$addressee！',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 108),
                child: Text(
                  '需要日用品？請點柑仔店填寫物資需求；需要協助可問智慧小幫手',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _UpcomingEventsPanel(
                summaryLine: eventLine,
                events: upcomingEvents,
                onPrimary: colorScheme.onPrimary,
                onViewCalendar: () =>
                    ref.read(homeBottomNavIndexProvider.notifier).select(5),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          top: 16,
          child: _ChatShortcutCard(
            color: _orangeChat,
            onPrimary: colorScheme.onPrimary,
            onTap: () => context.push('/assistant'),
          ),
        ),
      ],
    );
  }
}

class _UpcomingEventsPanel extends StatefulWidget {
  const _UpcomingEventsPanel({
    required this.summaryLine,
    required this.events,
    required this.onPrimary,
    required this.onViewCalendar,
  });

  final String summaryLine;
  final List<CommunityEvent> events;
  final Color onPrimary;
  final VoidCallback onViewCalendar;

  @override
  State<_UpcomingEventsPanel> createState() => _UpcomingEventsPanelState();
}

class _UpcomingEventsPanelState extends State<_UpcomingEventsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final onPrimary = widget.onPrimary;
    final events = widget.events;
    final preview = events.take(6).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.summaryLine,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: onPrimary,
                            ),
                          ),
                          if (!_expanded && events.length > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              '點開查看近期 ${events.length} 項活動',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: onPrimary.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: onPrimary.withValues(alpha: 0.9),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(
                  height: 1,
                  color: onPrimary.withValues(alpha: 0.2),
                ),
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: onPrimary.withValues(alpha: 0.15),
                    ),
                  _HomeEventRow(
                    event: preview[i],
                    onPrimary: onPrimary,
                  ),
                ],
                if (events.length > preview.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Text(
                      '還有 ${events.length - preview.length} 項活動，請至活動頁查看',
                      style: TextStyle(
                        fontSize: 14,
                        color: onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: TextButton.icon(
                    onPressed: widget.onViewCalendar,
                    icon: Icon(Icons.calendar_month, color: onPrimary),
                    label: Text(
                      '查看活動日曆',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: onPrimary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: onPrimary,
                      backgroundColor: onPrimary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _HomeEventRow extends StatelessWidget {
  const _HomeEventRow({
    required this.event,
    required this.onPrimary,
  });

  final CommunityEvent event;
  final Color onPrimary;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  static const _procurementOrange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final isProcurement = CommunityProcurementDay.isVirtualEvent(event);
    final w = _weekdays[(event.eventDate.weekday - 1) % 7];
    final dateLabel =
        '${event.eventDate.month}/${event.eventDate.day}（週$w）';
    final accent = isProcurement ? _procurementOrange : onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                event.photoUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _EventThumbFallback(
                  isProcurement: isProcurement,
                  accent: accent,
                ),
              ),
            )
          else
            _EventThumbFallback(isProcurement: isProcurement, accent: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isProcurement)
                  Text(
                    '每週四固定採購',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: onPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onPrimary.withValues(alpha: 0.88),
                  ),
                ),
                if (event.location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: onPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventThumbFallback extends StatelessWidget {
  const _EventThumbFallback({
    required this.isProcurement,
    required this.accent,
  });

  final bool isProcurement;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isProcurement ? Icons.shopping_basket_outlined : Icons.event_outlined,
        color: accent,
        size: 24,
      ),
    );
  }
}

class _ChatShortcutCard extends StatelessWidget {
  const _ChatShortcutCard({
    required this.color,
    required this.onPrimary,
    required this.onTap,
  });

  final Color color;
  final Color onPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          height: 108,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.smart_toy, size: 40, color: onPrimary),
                const SizedBox(height: 6),
                Text(
                  '小幫手',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '協助查詢',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onPrimary.withValues(alpha: 0.9),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  static const _learningBlue = Color(0xFF1565C0);
  static const _hakkaTeal = Color(0xFF00695C);
  static const _transportGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LargeMenuCard(
                title: '社區學習',
                subtitle: '防詐宣導與健康教室',
                icon: Icons.menu_book_rounded,
                iconBackground: _learningBlue.withValues(alpha: 0.12),
                iconColor: _learningBlue,
                onTap: () => context.push('/community-learning'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _LargeMenuCard(
                title: '🗣️ 客語資訊',
                subtitle: '生活客語、歌謠與在地故事',
                icon: Icons.record_voice_over_rounded,
                iconBackground: _hakkaTeal.withValues(alpha: 0.12),
                iconColor: _hakkaTeal,
                onTap: () => context.push('/hakka-culture'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _LargeMenuCard(
          title: '社區交通',
          subtitle: '預約接送、長期接送與司機任務',
          icon: Icons.local_taxi_rounded,
          iconBackground: _transportGreen.withValues(alpha: 0.12),
          iconColor: _transportGreen,
          onTap: () => context.push('/transport'),
        ),
      ],
    );
  }
}

class _LargeMenuCard extends StatelessWidget {
  const _LargeMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Material(
      color: surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
