import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/home/presentation/home_page.dart';

/// 執行小幫手的一鍵帶路。
void assistantNavigate(
  BuildContext context,
  WidgetRef ref,
  AssistantNavAction action,
) {
  final tab = action.homeTab;
  if (tab != null) {
    ref.read(homeBottomNavIndexProvider.notifier).select(tab);
    context.go('/home?tab=$tab');
    return;
  }
  final route = action.route;
  if (route == null) return;
  if (route == '/home') {
    context.go('/home');
    return;
  }
  context.push(route);
}
