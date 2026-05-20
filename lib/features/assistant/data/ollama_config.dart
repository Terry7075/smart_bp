import 'package:flutter/foundation.dart';

/// Ollama／代理伺服器連線設定。
///
/// 編譯參數範例：
/// ```bash
/// flutter run -d chrome \
///   --dart-define=OLLAMA_API=http://127.0.0.1:8791 \
///   --dart-define=OLLAMA_MODEL=qwen2.5:7b
/// ```
///
/// - **Web**：預設走本機代理 [defaultProxyBase]（解 CORS），請先 `npm run assistant:ollama-proxy`。
/// - **手機／桌面**：預設直連 Ollama `http://127.0.0.1:11434`；Android 模擬器可用 `http://10.0.2.2:11434`。
class OllamaConfig {
  OllamaConfig._();

  static const String _apiBaseEnv = String.fromEnvironment('OLLAMA_API');
  static const String model = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'qwen2.5:7b',
  );

  static const String defaultOllamaBase = 'http://127.0.0.1:11434';
  static const String defaultProxyBase = 'http://127.0.0.1:8791';

  static String get apiBase {
    final env = _apiBaseEnv.trim();
    if (env.isNotEmpty) return _trimTrailingSlash(env);
    if (kIsWeb) return defaultProxyBase;
    return defaultOllamaBase;
  }

  static String _trimTrailingSlash(String url) {
    var s = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
