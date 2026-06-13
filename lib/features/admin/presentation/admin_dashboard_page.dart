import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 舊路由相容：管理後台已併入志工儀表板「數據總覽」Tab。
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/volunteer-dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      ),
    );
  }
}
