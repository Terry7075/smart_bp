import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notification_service.dart';
import 'core/shop_push_service.dart';
import 'core/router.dart';
import 'features/shared/offline_queue/offline_queue.dart';

// 👈 2. main 函式必須加上 async，因為連線到雲端需要等待
void main() async { 
  // 確保 Flutter 底層元件初始化，這對後續串接 Supabase 或 OCR 套件非常重要
  WidgetsFlutterBinding.ensureInitialized();

  // 👈 3. 在 runApp 之前，正式啟動 Supabase 雲端引擎！
  await Supabase.initialize(
    url: 'https://ntufhwqxaidwnelorcsv.supabase.co',        // ⚠️ 注意：這裡要換成你 Supabase 後台的 URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50dWZod3F4YWlkd25lbG9yY3N2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyMTc3NDIsImV4cCI6MjA5MDc5Mzc0Mn0.huSbIe7lqoUY-KTNgBl6ahMy8Px-6CS7s28gkQeJTaI',      // ⚠️ 注意：這裡要換成你 Supabase 後台的 anon key
  );

  // 初始化本機通知服務
  await NotificationService.instance.init();
  await ShopPushService.instance.init();

  // 初始化 Hive 離線佇列（網路恢復時 flush 同步 demand 草稿）
  await OfflineQueue.init();

  runApp(
    // ProviderScope 是 Riverpod 的核心，它負責存放應用程式所有的「狀態」
    // 沒有這層封裝，後續我們寫的功能模組就無法共享資料
    const ProviderScope(
      child: MinduApp(),
    ),
  );
}

class MinduApp extends StatefulWidget {
  const MinduApp({super.key});

  @override
  State<MinduApp> createState() => _MinduAppState();
}

class _MinduAppState extends State<MinduApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.instance.bindNavigate(appRouter.go);
      await NotificationService.instance.handleLaunchNotificationIfAny();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '明德 e 達人',
      debugShowCheckedModeBanner: false, // 隱藏開發標籤，讓畫面更乾淨
      theme: ThemeData(
        useMaterial3: true,
        // 定義明德社區專屬的森林綠色調
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
        ),
        // 重要：為長輩設計的全域大字體規範
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 22),
          bodyMedium: TextStyle(fontSize: 20),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}