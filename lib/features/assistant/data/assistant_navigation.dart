import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/home/presentation/home_page.dart';

/// 執行小幫手按鈕：可送出後續訊息，或導向 App 頁面。
Future<void> assistantPerformAction(
  BuildContext context,
  WidgetRef ref,
  AssistantNavAction action, {
  Future<void> Function(String message)? onSendMessage,
}) async {
  final followUp = action.sendMessageOnTap?.trim();
  if (followUp != null && followUp.isNotEmpty) {
    if (onSendMessage != null) {
      await onSendMessage(followUp);
      return;
    }
  }
  assistantNavigate(context, ref, action);
}

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
  final dest = Uri(
    path: route == '/home' ? '/home' : route,
    queryParameters:
        action.queryParameters?.isNotEmpty == true ? action.queryParameters : null,
  );
  if (route == '/home') {
    context.go(dest.toString());
    return;
  }
  context.push(dest.toString());
}
