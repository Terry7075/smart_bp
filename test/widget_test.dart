// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_bp/main.dart';

void main() {
  testWidgets('App boots smoke test', (WidgetTester tester) async {
    // 只驗證 widget tree 能啟動；避免依賴舊的 counter 範本與 Supabase 初始化。
    await tester.pumpWidget(const ProviderScope(child: MinduApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
