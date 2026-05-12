import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/presentation/shop_page.dart';

void main() {
  runApp(const ProviderScope(child: ShopPreviewApp()));
}

class ShopPreviewApp extends StatelessWidget {
  const ShopPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '明德 e 達人 - 物資採購預覽',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
        ),
      ),
      home: const Scaffold(
        appBar: _PreviewAppBar(),
        body: SafeArea(child: ShopPage()),
      ),
    );
  }
}

class _PreviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PreviewAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      centerTitle: true,
      title: const Text(
        '柑仔店（預覽）',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
