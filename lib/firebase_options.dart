// Firebase 設定檔。請執行 `flutterfire configure` 覆寫本檔，或見 docs/FCM_SETUP.md。
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  /// 是否已完成 Firebase 專案綁定（非占位值）。
  static bool get isConfigured => isAndroidFcmConfigured || isIosFirebaseConfigured;

  /// 本 App 遠端推播僅 Android FCM 使用。
  static bool get isAndroidFcmConfigured {
    if (kIsWeb) return false;
    return android.apiKey != _placeholder &&
        android.appId != _placeholder &&
        android.projectId != _placeholder;
  }

  static bool get isIosFirebaseConfigured {
    return ios.apiKey != _placeholder &&
        ios.appId != _placeholder &&
        ios.projectId != _placeholder;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM 不支援 Web 建置。');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'FCM 僅支援 iOS / Android。請執行 flutterfire configure。',
        );
    }
  }

  /// 來自 `android/app/google-services.json`（專案 smart-bp-1c925）。
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBhz00RQ1qJ6z8lj5ivPWJ8r98OrUyPM6Q',
    appId: '1:496234810237:android:1fb9fccffdb0492f97da14',
    messagingSenderId: '496234810237',
    projectId: 'smart-bp-1c925',
    storageBucket: 'smart-bp-1c925.firebasestorage.app',
  );

  /// 來自 `ios/Runner/GoogleService-Info.plist`（專案 smart-bp-1c925）。
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJ8m0Nij19-uHmDHsLI7BkPo7-EsutB4',
    appId: '1:496234810237:ios:a69c824746fc9a3e97da14',
    messagingSenderId: '496234810237',
    projectId: 'smart-bp-1c925',
    storageBucket: 'smart-bp-1c925.firebasestorage.app',
    iosBundleId: 'com.xuyuchen.smartBp',
  );
}
