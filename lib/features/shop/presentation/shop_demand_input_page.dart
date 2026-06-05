import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 相容舊路由：統一導向柑仔店主入口 `/shop`。
class ShopDemandInputPage extends StatefulWidget {
  const ShopDemandInputPage({super.key});

  @override
  State<ShopDemandInputPage> createState() => _ShopDemandInputPageState();
}

class _ShopDemandInputPageState extends State<ShopDemandInputPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/shop');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
