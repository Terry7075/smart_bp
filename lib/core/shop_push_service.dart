import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import 'fcm_background.dart';
import 'notification_service.dart';

/// Android-only FCM：註冊 token、前景／點擊導航。iOS 僅 Realtime + 本機通知。
class ShopPushService {
  ShopPushService._();
  static final ShopPushService instance = ShopPushService._();

  bool _initialized = false;
  bool _firebaseReady = false;

  static bool get isFirebaseReady => instance._firebaseReady;

  /// 是否支援遠端 FCM（僅 Android 且 Firebase 已設定）。
  static bool get supportsRemoteFcm =>
      !kIsWeb && Platform.isAndroid && DefaultFirebaseOptions.isAndroidFcmConfigured;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || !Platform.isAndroid) {
      if (kDebugMode && Platform.isIOS) {
        debugPrint(
          'ShopPushService: iOS 使用 Realtime／本機通知，不註冊 FCM',
        );
      }
      return;
    }

    if (!DefaultFirebaseOptions.isAndroidFcmConfigured) {
      if (kDebugMode) {
        debugPrint(
          'ShopPushService: Android Firebase 未設定（見 docs/FCM_SETUP.md）',
        );
      }
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.android,
      );
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      _firebaseReady = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPushService: Firebase 初始化失敗 ($e)');
      }
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await NotificationService.instance.requestPermission();

    await _registerCurrentToken(messaging);

    messaging.onTokenRefresh.listen((token) {
      unawaited(_registerFcmToken(token));
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _navigateFromMessage(initial);
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && _firebaseReady) {
        unawaited(_registerCurrentToken(messaging));
      }
    });
  }

  Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerFcmToken(token);
    }
  }

  Future<void> _registerFcmToken(String fcmToken) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.rpc(
        'register_device_token',
        params: {'p_fcm_token': fcmToken, 'p_platform': 'android'},
      );
      if (kDebugMode) {
        debugPrint('ShopPushService: 已註冊 FCM token (android)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPushService: register_device_token 失敗 $e');
      }
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    unawaited(
      NotificationService.instance.showShopPushFromRemoteMessage(message),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _navigateFromMessage(message);
  }

  void _navigateFromMessage(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && route.isNotEmpty) {
      NotificationService.instance.navigateToRoute(route);
      return;
    }
    final orderId = message.data['order_id'];
    if (orderId != null && orderId.isNotEmpty) {
      NotificationService.instance.navigateToRoute('/shop/orders/$orderId');
      return;
    }
    NotificationService.instance.navigateToRoute('/volunteer/shop-orders');
  }

  Future<void> registerToken(String fcmToken, {String platform = 'android'}) async {
    await Supabase.instance.client.rpc(
      'register_device_token',
      params: {'p_fcm_token': fcmToken, 'p_platform': platform},
    );
  }
}
