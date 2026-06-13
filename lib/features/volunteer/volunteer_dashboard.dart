// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/activities/volunteer_activities_manage.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/health_monitoring/presentation/volunteer_monitoring_tab.dart';
import 'package:smart_bp/features/medication/volunteer_drug_dictionary_add_page.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_content_manage.dart';
import 'package:smart_bp/features/volunteer/volunteer_members_tab.dart';
import 'package:smart_bp/features/volunteer/volunteer_batch_refill_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_batch_refill_tab.dart';
import 'package:smart_bp/features/volunteer/volunteer_shop_orders_page.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:smart_bp/features/volunteer/volunteer_task_provider.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_hub_analytics_tab.dart';
import 'package:smart_bp/features/shared/elder_phone_utils.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_shop_confirm_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _kVolunteerBlue = Color(0xFF1565C0);
const Color _kBackgroundCream = Color(0xFFFFF8E1);

/// 志工端透過 signed URL 下載照片時的有效期（秒）。
///
/// 1 小時：足夠志工開 sheet 查看 + 放大檢視 + 撥電話的時間，又不會長到讓網址
/// 被洩漏後可以一直被取用。
const int _kPhotoSignedUrlSeconds = 60 * 60;

/// 志工端主畫面分區。
enum _VolunteerSection { health, shop, learning, activities }

/// 志工任務儀表板（健康／物資代購／學習／活動）。
class VolunteerDashboard extends ConsumerStatefulWidget {
  const VolunteerDashboard({
    super.key,
    this.initialHealthTab = 0,
    this.initialShopTab = 0,
    this.openShopSection = false,
  });

  /// 健康分區子 Tab：0=藥單 1=批次代領 2=監測 3=藥典 4=會員管理
  final int initialHealthTab;

  /// 物資代購分區子 Tab：0=代購管理 1=數據總覽
  final int initialShopTab;

  /// 一進入就開啟「物資代購」分區（例如 `?tab=3` 導向數據總覽）
  final bool openShopSection;

  @override
  ConsumerState<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends ConsumerState<VolunteerDashboard> {
  late _VolunteerSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.openShopSection
        ? _VolunteerSection.shop
        : _VolunteerSection.health;
  }

  String get _sectionTitle => switch (_section) {
        _VolunteerSection.health => '志工 · 健康',
        _VolunteerSection.shop => '志工 · 柑仔店',
        _VolunteerSection.learning => '志工 · 學習',
        _VolunteerSection.activities => '志工 · 活動',
      };

  Future<void> _refreshHealth() async {
    await Future.wait([
      ref.read(volunteerTasksProvider.notifier).refresh(),
      Future<void>.delayed(Duration.zero, () {
        ref.invalidate(volunteerBatchRefillGroupsProvider);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      requiredRole: RoleGuardTarget.volunteer,
      child: Scaffold(
        backgroundColor: _kBackgroundCream,
        appBar: AppBar(
          backgroundColor: _kVolunteerBlue,
          foregroundColor: Colors.white,
          title: Text(
            _sectionTitle,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          toolbarHeight: 72,
          actions: [
            if (_section == _VolunteerSection.health)
              IconButton(
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh, size: 28),
                onPressed: _refreshHealth,
              ),
            if (_section == _VolunteerSection.shop)
              IconButton(
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh, size: 28),
                onPressed: () {
                  ref.invalidate(shopVolunteerOrdersProvider);
                },
              ),
            IconButton(
              tooltip: '交通管理',
              icon: const Icon(Icons.local_taxi, size: 28),
              onPressed: () => context.push('/transport'),
            ),
            IconButton(
              tooltip: '個人資料',
              icon: const Icon(Icons.person_outline, size: 28),
              onPressed: () => context.push('/profile'),
            ),
            IconButton(
              tooltip: '登出',
              icon: const Icon(Icons.logout, size: 28),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VolunteerSectionNav(
                selected: _section,
                onSelected: (s) => setState(() => _section = s),
              ),
              Expanded(child: _buildSectionBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBody() {
    return switch (_section) {
      _VolunteerSection.health =>
        _VolunteerHealthSection(
          onRefreshAll: _refreshHealth,
          initialTab: widget.initialHealthTab,
        ),
      _VolunteerSection.shop => _VolunteerShopSection(
          initialTab: widget.initialShopTab,
        ),
      _VolunteerSection.learning =>
        const VolunteerContentManagePage(embedded: true),
      _VolunteerSection.activities => const VolunteerActivitiesManagePage(),
    };
  }
}

/// 上方四個分區按鈕：健康、物資代購、學習、活動。
class _VolunteerSectionNav extends StatelessWidget {
  const _VolunteerSectionNav({
    required this.selected,
    required this.onSelected,
  });

  final _VolunteerSection selected;
  final ValueChanged<_VolunteerSection> onSelected;

  static const _items = <(_VolunteerSection, String, IconData)>[
    (_VolunteerSection.health, '健康', Icons.favorite),
    (_VolunteerSection.shop, '柑仔店', Icons.storefront_outlined),
    (_VolunteerSection.learning, '學習', Icons.menu_book),
    (_VolunteerSection.activities, '活動', Icons.event),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _SectionNavButton(
                label: _items[i].$2,
                icon: _items[i].$3,
                selected: selected == _items[i].$1,
                onTap: () => onSelected(_items[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionNavButton extends StatelessWidget {
  const _SectionNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kVolunteerBlue : _kVolunteerBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? Colors.white : _kVolunteerBlue,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : _kVolunteerBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 物資代購分區：代購管理、數據總覽。
class _VolunteerShopSection extends StatefulWidget {
  const _VolunteerShopSection({this.initialTab = 0});

  final int initialTab;

  @override
  State<_VolunteerShopSection> createState() => _VolunteerShopSectionState();
}

class _VolunteerShopSectionState extends State<_VolunteerShopSection> {
  late int _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _ShopSubNavButton(
                  label: '代購需求',
                  icon: Icons.shopping_bag_outlined,
                  selected: _subTab == 0,
                  onTap: () => setState(() => _subTab = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShopSubNavButton(
                  label: '數據總覽',
                  icon: Icons.bar_chart,
                  selected: _subTab == 1,
                  onTap: () => setState(() => _subTab = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _subTab == 0
              ? const VolunteerShopOrdersPage(embedded: true)
              : VolunteerHubAnalyticsTab(
                  onGoShoppingList: () => setState(() => _subTab = 0),
                ),
        ),
      ],
    );
  }
}

class _ShopSubNavButton extends StatelessWidget {
  const _ShopSubNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kVolunteerBlue : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : _kVolunteerBlue,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : _kVolunteerBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 健康分區：藥單協助、批次代領、長者監測。
class _VolunteerHealthSection extends ConsumerStatefulWidget {
  const _VolunteerHealthSection({
    required this.onRefreshAll,
    this.initialTab = 0,
  });

  final Future<void> Function() onRefreshAll;

  /// 0=藥單 1=批次代領 2=監測 3=藥典 4=會員管理
  final int initialTab;

  @override
  ConsumerState<_VolunteerHealthSection> createState() =>
      _VolunteerHealthSectionState();
}

class _VolunteerHealthSectionState extends ConsumerState<_VolunteerHealthSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab.clamp(0, 4);
    _tabController = TabController(length: 5, vsync: this, initialIndex: tab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(volunteerTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: _kVolunteerBlue.withValues(alpha: 0.06),
          child: TabBar(
            controller: _tabController,
            indicatorColor: _kVolunteerBlue,
            indicatorWeight: 3,
            labelColor: _kVolunteerBlue,
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: const [
              Tab(text: '藥單協助'),
              Tab(text: '🛵 批次代領'),
              Tab(text: '❤️ 長者監測'),
              Tab(text: '📖 新增藥典'),
              Tab(text: '👥 會員管理'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                color: _kVolunteerBlue,
                onRefresh: widget.onRefreshAll,
                child: asyncTasks.when(
                  loading: () => const _LoadingView(),
                  error: (e, _) => _ErrorView(
                    error: e,
                    onRetry: () =>
                        ref.read(volunteerTasksProvider.notifier).refresh(),
                  ),
                  data: (tasks) => tasks.isEmpty
                      ? const _EmptyView()
                      : _TaskListView(tasks: tasks),
                ),
              ),
              RefreshIndicator(
                color: _kVolunteerBlue,
                onRefresh: widget.onRefreshAll,
                child: const VolunteerBatchRefillTab(),
              ),
              const VolunteerMonitoringTab(),
              const VolunteerDrugDictionaryAddPage(),
              const VolunteerMembersTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  商城分區：上方兩顆切換鈕（代購管理 / 數據總覽）
// ============================================================================

enum _ShopView { orders, analytics }

/// 志工端「商城」分區：用兩顆按鈕切換「代購管理」與「據點數據總覽」。
class _VolunteerShopSection extends StatefulWidget {
  const _VolunteerShopSection({this.initialView = _ShopView.orders});

  final _ShopView initialView;

  @override
  State<_VolunteerShopSection> createState() => _VolunteerShopSectionState();
}

class _VolunteerShopSectionState extends State<_VolunteerShopSection> {
  late _ShopView _view = widget.initialView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _ShopViewButton(
                  label: '代購管理',
                  icon: Icons.shopping_basket,
                  selected: _view == _ShopView.orders,
                  onTap: () => setState(() => _view = _ShopView.orders),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShopViewButton(
                  label: '數據總覽',
                  icon: Icons.bar_chart,
                  selected: _view == _ShopView.analytics,
                  onTap: () => setState(() => _view = _ShopView.analytics),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_view) {
            _ShopView.orders => const VolunteerShopOrdersPage(embedded: true),
            _ShopView.analytics => const VolunteerHubAnalyticsTab(),
          },
        ),
      ],
    );
  }
}

class _ShopViewButton extends StatelessWidget {
  const _ShopViewButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _kVolunteerBlue
          : _kVolunteerBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : _kVolunteerBlue,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : _kVolunteerBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  健康分區：Loading / Error / Empty
// ============================================================================

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    // 用 ListView 包，讓 RefreshIndicator 在「沒有資料時」也能下拉。
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: _kVolunteerBlue,
            ),
          ),
        ),
        SizedBox(height: 20),
        Center(
          child: Text(
            '正在抓取最新的長輩需求…',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kVolunteerBlue,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline,
            size: 72, color: Color(0xFFBF360C)),
        const SizedBox(height: 16),
        Text(
          '讀取任務清單失敗：\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
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
            backgroundColor: _kVolunteerBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.check_circle_outline,
            size: 96, color: _kVolunteerBlue),
        SizedBox(height: 24),
        Text(
          '太棒了！\n目前沒有待處理的任務。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _kVolunteerBlue,
            height: 1.5,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '感謝您的辛勞，下拉可以重新整理。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  任務清單 + Card
// ============================================================================

class _TaskListView extends StatelessWidget {
  const _TaskListView({required this.tasks});

  final List<VolunteerTask> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final VolunteerTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInProgress = task.status == VolunteerTaskStatus.inProgress;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isInProgress
              ? _kVolunteerBlue
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: task.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _relativeTime(task.createdAt),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.person, size: 24, color: Color(0xFF424242)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.elderName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (task.hospitalName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 24, color: Color(0xFF424242)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.hospitalName!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '點此查看詳情 ›',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kVolunteerBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _TaskDetailSheet(task: task, parentRef: ref),
    );
  }

  /// 「3 分鐘前 / 2 小時前 / 昨天 / 3 天前」之類的相對時間。
  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${when.year}/${when.month}/${when.day}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final VolunteerTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      VolunteerTaskStatus.pending => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100)
        ),
      VolunteerTaskStatus.inProgress => (
          const Color(0xFFE3F2FD),
          _kVolunteerBlue
        ),
      VolunteerTaskStatus.active => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32)
        ),
      VolunteerTaskStatus.done => (
          const Color(0xFFE0F2F1),
          const Color(0xFF00695C)
        ),
      VolunteerTaskStatus.cancelled => (
          const Color(0xFFEEEEEE),
          Colors.black54
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

// ============================================================================
//  詳情 Bottom Sheet：認領 / 撥打電話 / 標記完成
// ============================================================================

class _TaskDetailSheet extends ConsumerStatefulWidget {
  const _TaskDetailSheet({required this.task, required this.parentRef});

  final VolunteerTask task;

  /// 用 parent 的 [WidgetRef] 才能正確讀取 [volunteerTasksProvider]，避免
  /// bottom sheet 在自己的 Navigator 內 ref 拿不到上層 provider。
  final WidgetRef parentRef;

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  bool _isWorking = false;

  Future<void> _withBusy(Future<void> Function() action) async {
    setState(() => _isWorking = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _claim() async {
    final messenger = ScaffoldMessenger.of(context);
    await _withBusy(() async {
      try {
        await widget.parentRef
            .read(volunteerTasksProvider.notifier)
            .claim(widget.task.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: _kVolunteerBlue,
            duration: Duration(seconds: 4),
            content: Text(
              '✅ 已認領！記得儘快聯絡長輩確認藥單。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } catch (e) {
        print('[Volunteer] claim error: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFBF360C),
            duration: const Duration(seconds: 5),
            content: Text(
              '$e',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        // 失敗時別關 sheet，方便志工再試一次或看到最新清單。
      }
    });
  }

  /// 開啟人工補登表單（醫院 / 領藥日 / 服藥時段）。
  ///
  /// 表單 submit 完成才會把 detail sheet 一起 pop 掉並顯示成功 SnackBar；
  /// 中途取消則只關表單，detail sheet 仍開著，志工可隨時改主意。
  Future<void> _openVerifyForm() async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<_VerifyFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _VerifyFormSheet(
        initialHospital: widget.task.hospitalName,
      ),
    );

    if (result == null || !mounted) return;

    await _withBusy(() async {
      try {
        await widget.parentRef
            .read(volunteerTasksProvider.notifier)
            .verify(
              taskId: widget.task.id,
              hospitalName: result.hospital,
              pickupDate: result.pickupDate,
              takeMedicineTimes: result.times,
            );
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
            content: Text(
              '🎉 已回傳給長輩，鬧鐘會自動幫他/她設定好！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } catch (e) {
        print('[Volunteer] verify error: $e');
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFBF360C),
            duration: const Duration(seconds: 5),
            content: Text(
              '回傳失敗：$e',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    });
  }

  Future<void> _callElder() async {
    await VolunteerShopConfirmDialog.launchTelForElder(
      context,
      elderUserId: widget.task.elderId,
      fallbackPhone: widget.task.elderPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isMine = me != null && task.isClaimedBy(me);
    final canCall = task.elderId.trim().isNotEmpty;
    final displayPhone = ElderPhoneUtils.formatForDisplay(task.elderPhone) ??
        task.elderPhone;
    final hasDisplayPhone = (displayPhone ?? '').isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Stack(
        children: [
          ListView(
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
              Row(
                children: [
                  _StatusChip(status: task.status),
                  const SizedBox(width: 12),
                  Text(
                    '任務詳情',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kVolunteerBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailRow(icon: Icons.person, label: '長輩姓名', value: task.elderName),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.phone,
                label: '聯絡電話',
                value: hasDisplayPhone ? displayPhone! : '（沒有提供，仍可嘗試撥號）',
              ),
              if (task.hospitalName != null) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.local_hospital_outlined,
                  label: '看診醫院',
                  value: task.hospitalName!,
                ),
              ],
              const SizedBox(height: 20),
              if (task.hasPhoto) ...[
                const Text(
                  '📷 藥單原始照片',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _TaskPhotoView(photoPath: task.photoPath!),
                const SizedBox(height: 20),
              ],
              const Text(
                '🧾 OCR 辨識文字（系統自動讀取，僅供參考）',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: SelectableText(
                  task.rawOcrText.isEmpty ? '（沒有抓到文字）' : task.rawOcrText,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (task.isOpen)
                _PrimaryButton(
                  label: '🙋 我接下這件任務',
                  color: _kVolunteerBlue,
                  onPressed: _isWorking ? null : _claim,
                ),
              if (isMine && task.status == VolunteerTaskStatus.inProgress) ...[
                _PrimaryButton(
                  label: canCall ? '📞 撥打電話給長輩' : '📞 無法撥號',
                  color: _kVolunteerBlue,
                  onPressed: _isWorking || !canCall ? null : _callElder,
                ),
                const SizedBox(height: 12),
                _PrimaryButton(
                  label: '📝 填表確認並回傳',
                  color: const Color(0xFF2E7D32),
                  onPressed: _isWorking ? null : _openVerifyForm,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed:
                      _isWorking ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black26, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '取消，返回清單',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_isWorking)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: CircularProgressIndicator(
                    color: _kVolunteerBlue,
                    strokeWidth: 6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.black54),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  原始藥單照片：signed URL 下載 → 縮圖；點擊放大全螢幕檢視
// ============================================================================

class _TaskPhotoView extends StatefulWidget {
  const _TaskPhotoView({required this.photoPath});

  final String photoPath;

  @override
  State<_TaskPhotoView> createState() => _TaskPhotoViewState();
}

class _TaskPhotoViewState extends State<_TaskPhotoView> {
  late Future<String> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = _createSignedUrl();
  }

  /// Storage 是 Private bucket，因此每次顯示都要產一張 signed URL。
  ///
  /// 為了避免每次 `setState` 都重抓 signed URL，我們把 Future 存起來；
  /// 重整功能由 [_retry] 主動換新 Future 觸發。
  Future<String> _createSignedUrl() async {
    final client = Supabase.instance.client;
    return client.storage
        .from(volunteerTaskPhotosBucket)
        .createSignedUrl(widget.photoPath, _kPhotoSignedUrlSeconds);
  }

  void _retry() {
    setState(() {
      _signedUrlFuture = _createSignedUrl();
    });
  }

  void _openFullscreen(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoView(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _photoBox(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: _kVolunteerBlue,
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _photoBox(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      size: 56, color: Color(0xFFBF360C)),
                  const SizedBox(height: 12),
                  const Text(
                    '照片讀取失敗',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBF360C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新讀取'),
                  ),
                ],
              ),
            ),
          );
        }
        final url = snapshot.data!;
        return _photoBox(
          child: InkWell(
            onTap: () => _openFullscreen(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: _kVolunteerBlue,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.broken_image_outlined,
                          size: 56, color: Color(0xFFBF360C)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新讀取'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _photoBox({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }
}

/// 全螢幕照片檢視：用 [InteractiveViewer] 提供雙指縮放 / 拖曳，
/// 讓志工可以放大看模糊的處方細節。
class _FullscreenPhotoView extends StatelessWidget {
  const _FullscreenPhotoView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '藥單原圖',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, _, _) => const Center(
                child: Text(
                  '照片讀取失敗',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  人工補登表單：醫院 / 領藥日 / 服藥時段
// ============================================================================

/// 服藥時段預設選項；志工勾完後直接送 DB，剛好對得上 NotificationService
/// 解析「HH:mm」字串排程的格式，不必再 mapping。
class _MedicineSlot {
  const _MedicineSlot(this.label, this.time);
  final String label;
  final String time;
}

const List<_MedicineSlot> _kMedicineSlots = <_MedicineSlot>[
  _MedicineSlot('☀️ 早上 (08:00)', '08:00'),
  _MedicineSlot('🕛 中午 (13:00)', '13:00'),
  _MedicineSlot('🌙 晚上 (19:00)', '19:00'),
  _MedicineSlot('🛏️ 睡前 (22:00)', '22:00'),
];

/// 表單填完的結果：[hospital] 已 trim、[times] 已依時段順序排好。
class _VerifyFormResult {
  const _VerifyFormResult({
    required this.hospital,
    required this.pickupDate,
    required this.times,
  });

  final String hospital;
  final DateTime pickupDate;
  final List<String> times;
}

/// 志工人工補登表單（DraggableScrollableSheet）。
///
/// - 表單採本地 state，submit 時才驗證 + pop 回 `_VerifyFormResult`。
/// - 為什麼不在 sheet 內直接呼叫 `verify()`？
///   把 IO（呼叫 Supabase）留在外層 `_TaskDetailSheet` 處理，能共用其
///   `_withBusy` 遮罩 + 錯誤 SnackBar 流程，sheet 本身保持單純的「表單元件」。
class _VerifyFormSheet extends StatefulWidget {
  const _VerifyFormSheet({this.initialHospital});

  /// OCR 解析到的醫院名（如果有）會預填到 TextField，志工可以直接修正。
  final String? initialHospital;

  @override
  State<_VerifyFormSheet> createState() => _VerifyFormSheetState();
}

class _VerifyFormSheetState extends State<_VerifyFormSheet> {
  late final TextEditingController _hospitalController;
  DateTime? _pickupDate;
  final Set<String> _selectedTimes = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _hospitalController =
        TextEditingController(text: widget.initialHospital ?? '');
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _pickupDate ?? now.add(const Duration(days: 28));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      // 慢箋最多 90 天份，加緩衝設一年內。
      lastDate: now.add(const Duration(days: 365)),
      helpText: '選擇下次領藥日',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked != null && mounted) {
      setState(() => _pickupDate = picked);
    }
  }

  void _toggleTime(String time) {
    setState(() {
      if (_selectedTimes.contains(time)) {
        _selectedTimes.remove(time);
      } else {
        _selectedTimes.add(time);
      }
    });
  }

  String? _validate() {
    if (_hospitalController.text.trim().isEmpty) return '請輸入醫院名稱';
    if (_pickupDate == null) return '請選擇下次領藥日';
    if (_selectedTimes.isEmpty) return '請至少勾選一個服藥時段';
    return null;
  }

  void _submit() {
    if (_submitting) return;

    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFBF360C),
          duration: const Duration(seconds: 3),
          content: Text(
            err,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    // 依預設選項順序輸出，符合「08:00 → 13:00 → 19:00 → 22:00」直覺排序。
    final orderedTimes = <String>[
      for (final slot in _kMedicineSlots)
        if (_selectedTimes.contains(slot.time)) slot.time,
    ];

    Navigator.of(context).pop(
      _VerifyFormResult(
        hospital: _hospitalController.text.trim(),
        pickupDate: _pickupDate!,
        times: orderedTimes,
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year} 年 ${d.month} 月 ${d.day} 日';

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: ListView(
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
            const SizedBox(height: 12),
            Text(
              '📝 人工補登表單',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _kVolunteerBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '請對照藥單原圖，幫長輩補上下面三個欄位，\n按下「確認並回傳」後系統會自動幫長輩設定鬧鐘。',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            const _FieldLabel(icon: '🏥', label: '醫院 / 診所名稱'),
            const SizedBox(height: 8),
            TextField(
              controller: _hospitalController,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '例如：明德內科診所',
                hintStyle: const TextStyle(fontSize: 18, color: Colors.black38),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.black26, width: 1.4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _kVolunteerBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const _FieldLabel(icon: '📅', label: '下次領藥日'),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pickupDate != null
                        ? _kVolunteerBlue
                        : Colors.black26,
                    width: _pickupDate != null ? 2 : 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 24,
                      color: _pickupDate != null
                          ? _kVolunteerBlue
                          : Colors.black54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickupDate != null
                            ? _formatDate(_pickupDate!)
                            : '點此選擇日期',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _pickupDate != null
                              ? Colors.black87
                              : Colors.black38,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const _FieldLabel(icon: '⏰', label: '每日吃藥時段（可複選）'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final slot in _kMedicineSlots)
                  _SlotChoiceChip(
                    label: slot.label,
                    selected: _selectedTimes.contains(slot.time),
                    onTap: () => _toggleTime(slot.time),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '✅ 確認並回傳',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black26, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// 服藥時段大型可勾選 Chip：48dp 高、容易按。
class _SlotChoiceChip extends StatelessWidget {
  const _SlotChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = _kVolunteerBlue;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color:
              selected ? activeColor.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : Colors.black26,
            width: selected ? 2 : 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank,
              size: 24,
              color: selected ? activeColor : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: selected ? activeColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
