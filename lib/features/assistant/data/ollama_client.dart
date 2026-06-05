import 'package:dio/dio.dart';
import 'package:smart_bp/features/assistant/data/ollama_config.dart';

/// @deprecated 手機 App 不使用本機 Ollama；閒聊改 [AssistantGeminiCasualService]。
/// 僅保留供 Web 本機開發實驗，正式路徑見 [AssistantReplyOrchestrator]。

/// 呼叫 Ollama Chat API 失敗時拋出。
class OllamaException implements Exception {
  OllamaException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 透過 Dio 呼叫 Ollama `POST /api/chat`、`GET /api/tags`。
class OllamaClient {
  OllamaClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String get _base => OllamaConfig.apiBase;

  /// 確認 Ollama（或代理後的 Ollama）是否在線。
  Future<bool> ping() async {
    try {
      await _dio.get<dynamic>(
        '$_base/api/tags',
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 送出對話；[messages] 為 Ollama 格式 `{role, content}`。
  Future<String> chat({
    required List<Map<String, String>> messages,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_base/api/chat',
        data: <String, dynamic>{
          'model': OllamaConfig.model,
          'messages': messages,
          'stream': false,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      final content = data?['message']?['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
      throw OllamaException('小幫手沒有回覆內容，請換個問題試試。');
    } on DioException catch (e) {
      throw OllamaException(_friendlyDioMessage(e), cause: e);
    } catch (e) {
      if (e is OllamaException) rethrow;
      throw OllamaException('連線小幫手時發生錯誤，請稍後再試。', cause: e);
    }
  }

  String _friendlyDioMessage(DioException e) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return '無法連到小幫手。\n'
          '請確認已執行 ollama serve'
          '${OllamaConfig.apiBase.contains('8791') ? '，且本機已啟動 npm run assistant:ollama-proxy' : ''}。';
    }
    final status = e.response?.statusCode;
    if (status == 404) {
      return '找不到模型「${OllamaConfig.model}」。請在本機執行：ollama pull ${OllamaConfig.model}';
    }
    final body = e.response?.data;
    if (body is Map && body['error'] != null) {
      return body['error'].toString();
    }
    return '小幫手暫時無法回應（${e.message ?? '未知錯誤'}）。';
  }
}
