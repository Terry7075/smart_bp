import 'package:dio/dio.dart';

class PxThumbMemoryCache {
  static const int _max = 600;
  static final Map<String, String> _map = <String, String>{};
  static final List<String> _order = <String>[];

  static String _key({String? cacheKey, required String keyword, String? productId}) {
    final ck = cacheKey?.trim();
    if (ck != null && ck.isNotEmpty) return 'id:$ck';
    return '${keyword.trim()}\u0000${(productId ?? '').trim()}';
  }

  static String? get({String? cacheKey, required String keyword, String? productId}) {
    final k = _key(cacheKey: cacheKey, keyword: keyword, productId: productId);
    final v = _map[k];
    if (v == null) return null;
    // touch (簡單 LRU)
    _order.remove(k);
    _order.add(k);
    return v;
  }

  static void set({String? cacheKey, required String keyword, String? productId, required String url}) {
    final u = url.trim();
    if (u.isEmpty) return;
    final k = _key(cacheKey: cacheKey, keyword: keyword, productId: productId);
    if (_map.containsKey(k)) {
      _map[k] = u;
      _order.remove(k);
      _order.add(k);
      return;
    }
    _map[k] = u;
    _order.add(k);
    while (_order.length > _max) {
      final oldest = _order.removeAt(0);
      _map.remove(oldest);
    }
  }
}

/// 呼叫本機／自建的全聯「搜尋結果第一張縮圖」服務（見 `scripts/px_search_thumb_server.mjs`）。
///
/// 編譯時：`--dart-define=PX_SEARCH_THUMB_API=http://127.0.0.1:8790`
/// Android 模擬器請用 `http://10.0.2.2:8790`。
Future<String?> fetchPxSearchThumbnail({
  required String apiBase,
  required String keyword,
  String? pxProductId,
  String? cacheKey,
}) async {
  final kw = keyword.trim();
  if (apiBase.trim().isEmpty || kw.isEmpty) return null;

  final pid = pxProductId?.trim();
  final cached = PxThumbMemoryCache.get(cacheKey: cacheKey, keyword: kw, productId: pid);
  if (cached != null && cached.isNotEmpty) return cached;

  final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;

  Future<String?> once() async {
    final r = await Dio().get<Map<String, dynamic>>(
      '$base/px-search-thumb',
      queryParameters: {
        'keyword': kw,
        if (pid != null && pid.isNotEmpty) 'product_id': pid,
      },
      options: Options(
        // server 端會序列化請求；商品多時排隊很容易超過 40s，導致前端直接變占位圖
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    final data = r.data;
    if (data == null || data['ok'] != true) return null;
    final u = data['image_url']?.toString().trim();
    if (u == null || u.isEmpty) return null;
    PxThumbMemoryCache.set(cacheKey: cacheKey, keyword: kw, productId: pid, url: u);
    return u;
  }

  try {
    final u1 = await once();
    if (u1 != null) return u1;
    // 偶發版面/網路抖動：短暫等一下再試一次
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return await once();
  } catch (_) {
    return null;
  }
}
