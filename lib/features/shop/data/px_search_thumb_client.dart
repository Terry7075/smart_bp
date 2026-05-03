import 'package:dio/dio.dart';

/// 呼叫本機／自建的全聯「搜尋結果第一張縮圖」服務（見 `scripts/px_search_thumb_server.mjs`）。
///
/// 編譯時：`--dart-define=PX_SEARCH_THUMB_API=http://127.0.0.1:8790`
/// Android 模擬器請用 `http://10.0.2.2:8790`。
Future<String?> fetchPxSearchThumbnail({
  required String apiBase,
  required String keyword,
  String? pxProductId,
}) async {
  final kw = keyword.trim();
  if (apiBase.trim().isEmpty || kw.isEmpty) return null;

  final pid = pxProductId?.trim();
  final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
  try {
    final r = await Dio().get<Map<String, dynamic>>(
      '$base/px-search-thumb',
      queryParameters: {
        'keyword': kw,
        if (pid != null && pid.isNotEmpty) 'product_id': pid,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    final data = r.data;
    if (data == null || data['ok'] != true) return null;
    final u = data['image_url']?.toString().trim();
    if (u == null || u.isEmpty) return null;
    return u;
  } catch (_) {
    return null;
  }
}
