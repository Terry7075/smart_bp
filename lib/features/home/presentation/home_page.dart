// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_page.dart';

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
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const List<String> _bottomNavLabels = [
    '首頁',
    '柑仔店',
    '交通',
    '健康',
    '學習',
    '活動',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final navIndex = ref.watch(homeBottomNavIndexProvider);

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
                    print('點擊了 個人資料');
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(colorScheme: colorScheme),
              const SizedBox(height: 20),
              const _ActionGrid(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navIndex,
        onTap: (index) {
          print('點擊了 ${_bottomNavLabels[index]}');
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ShopPage(),
              ),
            );
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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '翁',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: onPrimary,
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.colorScheme});

  final ColorScheme colorScheme;

  static const _orangeChat = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
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
                  '早安，翁爺爺！',
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
