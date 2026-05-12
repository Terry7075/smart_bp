// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/core/notification_service.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/health/presentation/health_page.dart';
import 'package:smart_bp/features/prescription/prescription_provider.dart';
import 'package:smart_bp/features/profile/profile_provider.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';
import 'package:smart_bp/features/volunteer/volunteer_task_provider.dart';

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
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<String> _bottomNavLabels = [
    '首頁',
    '柑仔店',
    '交通',
    '健康',
    '學習',
    '活動',
  ];

  /// 上次 stream 觀察到的 status，用來偵測「pending/in_progress → active」轉換。
  ///
  /// 為什麼不用 didUpdateWidget？因為 stream 是 Riverpod async value，我們改用
  /// `ref.listen` 在 [build] 內監聽，把前次值存在 state 即可。
  VolunteerTaskStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navIndex = ref.watch(homeBottomNavIndexProvider);

    // 觀察「我自己最新一筆藥單任務」的 Realtime stream；當志工剛把
    // status 推到 active 時，我們在這裡幫長輩自動排提醒 + 顯示 SnackBar。
    ref.listen<AsyncValue<VolunteerTask?>>(
      latestPrescriptionStreamProvider,
      _onLatestPrescriptionChanged,
    );

    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: _buildScaffold(context, ref, colorScheme, navIndex),
    );
  }

  /// `latestPrescriptionStreamProvider` 變化時的副作用處理。
  ///
  /// 關鍵：只有「上一個非 active → 這次 active」這條轉換才會觸發
  /// `schedulePrescriptionReminders` + SnackBar，避免 App 開啟時因為一進來就拿到
  /// `active` 而誤排或重複叮咚。
  void _onLatestPrescriptionChanged(
    AsyncValue<VolunteerTask?>? previous,
    AsyncValue<VolunteerTask?> next,
  ) {
    final task = next.value;
    if (task == null) return;

    final wasActiveAlready = _lastStatus == VolunteerTaskStatus.active;
    final justBecameActive =
        task.status == VolunteerTaskStatus.active && !wasActiveAlready;

    // 不論是否觸發副作用，先更新 _lastStatus 才不會反覆 fire。
    final hadPrior = _lastStatus != null;
    _lastStatus = task.status;

    // 第一次拿到資料（_lastStatus 原本是 null）即使是 active 也不該觸發，
    // 否則 App 冷啟時會把舊任務重排一次。
    if (!hadPrior) return;
    if (!justBecameActive) return;

    // 真的是「剛剛被志工確認」這條轉換——排提醒 + SnackBar。
    _scheduleAndNotify(task);
  }

  Future<void> _scheduleAndNotify(VolunteerTask task) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final pickup = task.pickupDate ?? DateTime.now();
      await ref.read(prescriptionRepositoryProvider).upsertVolunteerPrescription(
            id: task.id,
            userId: task.elderId,
            hospitalName: task.hospitalName,
            pickupDate: pickup,
            takeMedicineTimes: task.takeMedicineTimes,
          );
      await NotificationService.instance.schedulePrescriptionReminders(
        prescriptionId: task.id,
        takeMedicineTimes: task.takeMedicineTimes,
        pickupDate: task.pickupDate,
        hospitalName: task.hospitalName,
      );
      ref.invalidate(activePrescriptionsProvider);
    } catch (e) {
      print('[Home] auto schedule reminders error: $e');
    }

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 6),
        content: Text(
          '📢 志工已完成確認，並幫您設好吃藥提醒囉！',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
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
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GreetingCard(),
                    const SizedBox(height: 16),
                    const _TaskStatusCard(),
                    const SizedBox(height: 20),
                    const _ActionGrid(),
                    const SizedBox(height: 16),
                    const _HealthScanBanner(),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navIndex,
        onTap: (index) {
          print('點擊了 ${_bottomNavLabels[index]}');
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
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school),
            label: '學習',
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

  /// 將姓名加上適當稱謂：兩字以上 → 「○○ 您好」；單字 → 直接稱呼。
  /// 取不到名字時 fallback 為「長輩」，避免顯示空字串。
  String _addressFromName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '長輩';
    return trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final asyncProfile = ref.watch(profileProvider);

    final greeting = greetingForNow();
    final addressee = asyncProfile.maybeWhen(
      data: (p) => _addressFromName(p?.name),
      orElse: () => '長輩',
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
                  '今天天氣不錯，來去社區走走？',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '下次共餐：11/15（週五）',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          top: 16,
          child: _ChatShortcutCard(color: _orangeChat, onPrimary: colorScheme.onPrimary),
        ),
      ],
    );
  }
}

// ============================================================================
//  任務狀態即時監聽卡片：依 Realtime stream 顯示「等志工 / 已確認」
// ============================================================================

/// 長輩首頁顯示「最新一張藥單目前進度」的卡片。
///
/// 設計原則：
/// - 沒有任何任務時直接 `SizedBox.shrink()`，不打擾首頁版面。
/// - `pending` / `inProgress` 都顯示成「⏳ 志工正在幫您看藥單中」的橘色等待卡。
/// - `active` 顯示綠色成功卡 + 領藥日 + 服藥時段。
/// - `done` / `cancelled` 視為「歷史單」也不顯示，避免長輩疑惑。
///
/// 實際 schedule 提醒 + SnackBar 由首頁 `ref.listen` 處理，這個卡片只負責顯示。
class _TaskStatusCard extends ConsumerWidget {
  const _TaskStatusCard();

  static const _waitOrange = Color(0xFFE65100);
  static const _waitOrangeBg = Color(0xFFFFF3E0);
  static const _doneGreen = Color(0xFF2E7D32);
  static const _doneGreenBg = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTask = ref.watch(latestPrescriptionStreamProvider);

    return asyncTask.when(
      // Stream 第一次連線（loading）/ 連線錯誤都不擋首頁，靜默。
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (task) {
        if (task == null) return const SizedBox.shrink();

        switch (task.status) {
          case VolunteerTaskStatus.pending:
          case VolunteerTaskStatus.inProgress:
            return _buildWaitingCard(task);
          case VolunteerTaskStatus.active:
            return _buildActiveCard(task);
          case VolunteerTaskStatus.done:
          case VolunteerTaskStatus.cancelled:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildWaitingCard(VolunteerTask task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _waitOrangeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _waitOrange.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: _waitOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⏳ 志工正在幫您看藥單中…',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _waitOrange,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '請耐心等候，村辦公室確認完畢後\n會立刻通知您！',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBF360C),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(VolunteerTask task) {
    final pickupText = task.pickupDate != null
        ? '${task.pickupDate!.year} 年 ${task.pickupDate!.month} 月 ${task.pickupDate!.day} 日'
        : '（志工尚未填）';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _doneGreenBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _doneGreen.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 32, color: _doneGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ 志工已幫您設定好鬧鐘！',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _doneGreen,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (task.hospitalName != null && task.hospitalName!.isNotEmpty) ...[
            _ActiveRow(
              icon: '🏥',
              label: '看診醫院',
              value: task.hospitalName!,
            ),
            const SizedBox(height: 8),
          ],
          _ActiveRow(
            icon: '📅',
            label: '下次領藥日',
            value: pickupText,
            valueColor: const Color(0xFFC62828),
          ),
          const SizedBox(height: 8),
          _ActiveRow(
            icon: '⏰',
            label: '吃藥時段',
            value: task.takeMedicineTimes.isEmpty
                ? '（未設定）'
                : task.takeMedicineTimes.join('、'),
          ),
        ],
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatShortcutCard extends StatelessWidget {
  const _ChatShortcutCard({
    required this.color,
    required this.onPrimary,
  });

  final Color color;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => print('點擊了 聊聊天'),
        child: SizedBox(
          width: 96,
          height: 96,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.smart_toy, size: 40, color: onPrimary),
                const SizedBox(height: 6),
                Text(
                  '聊聊天',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: onPrimary,
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
  static const _transportGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LargeMenuCard(
            title: '社區學習',
            subtitle: '課程、講座與報名',
            icon: Icons.menu_book_rounded,
            iconBackground: _learningBlue.withValues(alpha: 0.12),
            iconColor: _learningBlue,
            onTap: () => print('點擊了 社區學習'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _LargeMenuCard(
            title: '交通查詢',
            subtitle: '公車與接駁資訊',
            icon: Icons.directions_car_filled_rounded,
            iconBackground: _transportGreen.withValues(alpha: 0.12),
            iconColor: _transportGreen,
            onTap: () => print('點擊了 交通查詢'),
          ),
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

/// 首頁「健康掃描」快捷入口：導向 OCR 掃描頁。
class _HealthScanBanner extends StatelessWidget {
  const _HealthScanBanner();

  static const _healthRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Material(
      color: _healthRed,
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/health-scan'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.document_scanner_rounded,
                  size: 36,
                  color: onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '健康處方籤掃描',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: onPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '拍照或從相簿辨識血壓、血糖與藥袋',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: onPrimary.withValues(alpha: 0.92),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 36, color: onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
