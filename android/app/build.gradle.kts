plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_bp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications v18+ 要求啟用 core library desugaring，
        // 讓 java.time、Stream 等 Java 8+ API 也能跑在舊版 Android。
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.smart_bp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // health 套件（Google Health Connect）要求 minSdk >= 26（Android 8.0）
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// google_mlkit_text_recognition 的非拉丁語系腳本（中 / 日 / 韓 / 天城文）需要
// 額外宣告對應的 bundled 模型依賴，否則呼叫 TextRecognizer(script=chinese)
// 會拋 NoClassDefFoundError 直接閃退。參考套件 README：
// https://pub.dev/packages/google_mlkit_text_recognition
dependencies {
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")

    // 搭配上方 compileOptions.isCoreLibraryDesugaringEnabled = true，
    // 提供 java.time / java.util.stream 等舊 Android 缺少的 API。
    // flutter_local_notifications 21.x 官方文件指定的版本下限是 2.1.4。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
