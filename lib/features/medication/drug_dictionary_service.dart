// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../prescription/prescription_models.dart';

/// 全 App 共用的藥典查詢服務（Riverpod singleton）。
///
/// 改成 Riverpod provider 後最大好處：`_imageUrlCache` 在 App 生命週期內持續
/// 有效，長輩在「打卡頁 ↔ 健康頁」之間來回切時不會每次都重打 Supabase。
final drugDictionaryServiceProvider = Provider<DrugDictionaryService>((ref) {
  return DrugDictionaryService();
});

// ============================================================================
//  查詢結果型別
// ============================================================================

/// 藥典圖片查詢結果。
///
/// 為什麼需要把「null」拆成三種？
/// - 舊版只回 `String?`，UI 把「沒比對到」「查詢逾時」「Supabase 例外」全部當
///   `null` 顯示「系統尚未建檔此藥物圖片」，會讓志工誤判（其實可能是網路問題
///   或 storage 權限掉了）。
/// - 拆成 sealed 後，UI 可以分別顯示「藥典沒這張」「藥典暫時連不上」這兩
///   種訊息，志工看到後判斷流程也比較清楚。
sealed class DrugImageLookup {
  const DrugImageLookup();
}

/// 比對成功且能解析到可用的圖片 URL。
///
/// [exactBrand]：
/// - `true`  → 藥典裡有「同藥廠的相同產品」（品牌詞吻合），圖片即長輩手中的藥。
/// - `false` → 只比對到「相同成分、不同藥廠」的產品；藥丸外觀可能不同，UI 需顯示
///   [referenceNote] 警語，避免長輩誤認。
class DrugImageMatched extends DrugImageLookup {
  const DrugImageMatched(
    this.imageUrl, {
    this.fallbackUrls = const [],
    this.exactBrand = true,
    this.referenceNote,
  });
  final String imageUrl;

  /// 同一比對層級的其他圖片網址；主 URL 載入失敗時 UI 依序嘗試（仍為
  /// 同款或同成分參考，不跨到不同學名）。
  final List<String> fallbackUrls;
  final bool exactBrand;

  /// 非完全同款時，要顯示給長輩看的提醒文字（例：相同成分、外觀可能不同）。
  final String? referenceNote;
}

/// 服務正常完成查詢，但藥典裡確實沒有匹配的列。
class DrugImageNotFound extends DrugImageLookup {
  const DrugImageNotFound();
}

/// 查詢過程出狀況（PostgREST 例外、Storage list 失敗、timeout 等）。
///
/// [reason] 給 console / 志工 debug 用，UI 不直接秀給長輩。
class DrugImageLookupFailed extends DrugImageLookup {
  const DrugImageLookupFailed(this.reason);
  final String reason;
}

/// 藥典（`drug_dictionary`）查詢：依藥名模糊比對圖片 URL。
///
/// 主要 entry：[fetchDrugImageForCandidates]。
///
/// ## 與舊版差異
///
/// - 舊版對每個 candidate × 每個 search term **序列**打 2~3 次 DB（最差
///   會有 10+ 次 round-trip），新版合併成單一 PostgREST `.or()` 查詢。
/// - 舊版 reverse 比對只抓「沒排序的 50 筆」做 client-side `contains`，
///   超過 50 筆的藥典就會隨機漏；新版 forward 全用 SQL ilike，reverse
///   再退而求其次 fetch up to 500 筆（社區型藥典夠用）。
/// - 舊版每次進打卡頁都重打，新版內建 [_imageUrlCache] in-memory 快取。
/// - 舊版沒有 timeout，網路差時 FutureBuilder 會一直轉；新版有
///   [_queryTimeout] 5 秒守門，逾時直接回 `null` 走 placeholder。
class DrugDictionaryService {
  DrugDictionaryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 「純檔名」格式（沒有 `bucket/path` 前綴）時，依序嘗試找圖片的候選 bucket。
  static const List<String> _candidateBuckets = [
    'drug-images',
    'drug_dictionary',
    'drugs',
  ];

  /// 單次查詢的總 timeout：包含 PostgREST 查藥典 + Storage 解析。
  /// 設 5 秒：足夠正常網路完成，但網路差時長輩不會看著轉圈轉太久。
  static const Duration _queryTimeout = Duration(seconds: 5);

  /// Reverse fallback 一次最多撈幾筆藥典做 client-side 子字串比對。
  ///
  /// 為什麼是 500？社區型藥典實務上不會超過這個量級；真的破表的話
  /// 請改寫成 RPC + `position(name_zh in lower($1)) > 0` 做 server-side。
  static const int _reverseSearchLimit = 500;

  /// 切詞時的「不要當搜尋字」黑名單（小寫比對）。沒有這層的話，
  /// 「Amlodipine 5mg tablets」會切出 `["amlodipine","tablets","5mg"]`，
  /// `tablets`、`mg` 也會被當搜尋詞，誤命中其他藥的機率非常高。
  static const Set<String> _stopTerms = {
    'mg', 'ml', 'mcg', 'iu', 'tab', 'tabs', 'tablet', 'tablets',
    'cap', 'caps', 'capsule', 'capsules', 'pill', 'pills',
    'oral', 'po', 'qd', 'bid', 'tid', 'qid', 'prn',
    '錠', '膠囊', '公克', '毫克', '微克',
  };

  /// 英文搜尋字最小長度。`mg`、`tab` 等太短，誤命中率高。
  static const int _minLatinTermLength = 3;

  /// 中文藥名常見 2 字（如「雅脈」），允許較短。
  static const int _minCjkTermLength = 2;

  /// Storage signed URL 有效秒數（與志工審單照片相同策略）。
  static const int _signedUrlTtlSeconds = 3600;

  /// 內存快取：以排序後的 candidate 字串組為 key。
  /// 命中時跳過 PostgREST + Storage list，可省下整個 round-trip。
  ///
  /// 注意：只快取 [DrugImageMatched] 與 [DrugImageNotFound]，**不快取**
  /// [DrugImageLookupFailed]——失敗通常是網路問題，下次重進頁面該允許 retry。
  final Map<String, DrugImageLookup> _imageUrlCache =
      <String, DrugImageLookup>{};

  /// 從一張處方紀錄的多個候選藥名查詢藥典圖片。
  ///
  /// 回傳 [DrugImageLookup] 區分三種情境：成功 / 找不到 / 查詢失敗。
  /// 全域 [_queryTimeout] 守門，逾時直接回 [DrugImageLookupFailed]。
  /// 從一張處方紀錄的多個候選藥名查詢藥典圖片。
  ///
  /// [genericNames]：藥品「學名／英文成分」清單（弱詞）。**只用來放寬資料庫
  /// 查詢的召回**，不能單獨成立比對——因為同學名不同藥廠的藥丸外觀不同，
  /// 若只靠學名命中就顯示圖會誤導長輩認藥。最終只採用「品牌詞」（候選藥名
  /// 去掉學名後）有吻合的藥典列。
  Future<DrugImageLookup> fetchDrugImageForCandidates(
    List<String> candidates, {
    List<String> genericNames = const [],
  }) async {
    if (candidates.isEmpty) return const DrugImageNotFound();

    final cacheKey = _cacheKey(candidates, genericNames);
    final cached = _imageUrlCache[cacheKey];
    if (cached != null) {
      print('[DrugDictionary] cache hit "$cacheKey"');
      return cached;
    }

    try {
      final matched = await _fetchImageForCandidates(candidates, genericNames)
          .timeout(_queryTimeout);
      final DrugImageLookup result = matched ?? const DrugImageNotFound();
      _imageUrlCache[cacheKey] = result;
      return result;
    } on TimeoutException catch (_) {
      print('[DrugDictionary] timeout looking up "$cacheKey"');
      return const DrugImageLookupFailed('查詢逾時（5 秒）');
    } catch (e, st) {
      print('[DrugDictionary] error looking up "$cacheKey": $e\n$st');
      return DrugImageLookupFailed(e.toString());
    }
  }

  /// 依藥名查詢藥典圖片（單一藥名版，留給呼叫端 ad-hoc 查詢使用）。
  Future<DrugImageLookup> fetchDrugImage(String drugName) =>
      fetchDrugImageForCandidates([drugName]);

  /// 清除指定候選藥名的快取（重試查詢前呼叫，避免 [DrugImageNotFound] 被永久命中）。
  void invalidateCache(List<String> candidates,
      {List<String> genericNames = const []}) {
    _imageUrlCache.remove(_cacheKey(candidates, genericNames));
  }

  String _cacheKey(List<String> candidates, List<String> genericNames) {
    final cleaned = candidates
        .map(_normalizeCandidateForCache)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final gen = genericNames
        .map(_normalizeCandidateForCache)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return '${cleaned.join('|')}##${gen.join('|')}';
  }

  static String _normalizeCandidateForCache(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<DrugImageMatched?> _fetchImageForCandidates(
    List<String> candidates,
    List<String> genericNames,
  ) async {
    final terms = <String>{};
    for (final raw in candidates) {
      terms.addAll(expandDrugLookupSearchTerms(raw));
    }
    // 複方學名（如 "Pioglitazone Metformin"）拆成各成分，提高藥典召回。
    for (final g in genericNames) {
      terms.addAll(expandGenericNameSearchTerms(g));
    }

    // 「品牌詞」= 全部候選詞 − 學名詞。只有品牌詞吻合才算「同藥廠產品」。
    final genericNormalized = <String>{};
    for (final g in genericNames) {
      for (final t in expandGenericNameSearchTerms(g)) {
        genericNormalized.add(_normalizeForSubstringMatch(t));
      }
    }
    final brandTerms = <String>{};
    for (final t in terms) {
      final n = _normalizeForSubstringMatch(t);
      if (n.isEmpty) continue;
      if (genericNormalized.contains(n)) continue;
      brandTerms.add(n);
    }

    // 一次取回 forward + reverse 候選列（reverse 只在 forward 沒撈到時才打）。
    final forwardRows = await _forwardSearch(terms);
    final reverseRows =
        forwardRows.isEmpty ? await _reverseSearch(candidates) : forwardRows;
    final allRows = forwardRows.isEmpty
        ? reverseRows
        : <Map<String, dynamic>>[...forwardRows, ...reverseRows];
    _sortRowsForImagePick(allRows);

    // 第一階：品牌詞吻合 → 視為「同藥廠相同產品」，顯示其圖（exactBrand=true）。
    final brandUrls = await _collectBrandMatchedImageUrls(allRows, brandTerms);
    if (brandUrls.isNotEmpty) {
      print('[DrugDictionary] brand match: primary=${brandUrls.first}');
      return DrugImageMatched(
        brandUrls.first,
        fallbackUrls: brandUrls.length > 1 ? brandUrls.sublist(1) : const [],
        exactBrand: true,
      );
    }

    // 第二階：沒有品牌吻合，但有「相同成分（學名）」的列 → 顯示圖但加警語。
    final genericUrls = await _collectResolvableImageUrls(allRows);
    if (genericUrls.isNotEmpty) {
      print('[DrugDictionary] generic fallback: primary=${genericUrls.first}');
      return DrugImageMatched(
        genericUrls.first,
        fallbackUrls:
            genericUrls.length > 1 ? genericUrls.sublist(1) : const [],
        exactBrand: false,
        referenceNote: _buildReferenceNote(genericNames),
      );
    }

    print(
      '[DrugDictionary] no entry matched: candidates=$candidates '
      'brandTerms=$brandTerms',
    );
    return null;
  }

  /// 組「同成分參考圖」警語。有學名時帶上學名讓長輩／志工更清楚。
  String _buildReferenceNote(List<String> genericNames) {
    final gens = genericNames
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList();
    if (gens.isEmpty) {
      return '這可能是相同成分的另一款藥，外觀可能不同，僅供參考。';
    }
    return '這是相同成分（${gens.join('、')}）的另一款藥，'
        '外觀可能不同，請以手中藥袋為準，僅供參考。';
  }

  /// 收集「品牌詞吻合」列的可解析圖片 URL（去重、最多 [_maxImageUrlsPerTier] 筆）。
  Future<List<String>> _collectBrandMatchedImageUrls(
    List<Map<String, dynamic>> rows,
    Set<String> brandTerms,
  ) async {
    final out = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      if (!_rowMatchesBrand(row, brandTerms)) continue;
      final url = await _resolveImageUrl(row['image_url']);
      if (url != null && seen.add(url)) {
        out.add(url);
        if (out.length >= _maxImageUrlsPerTier) break;
      }
    }
    return out;
  }

  /// 收集所有可解析圖片 URL（同成分 fallback；去重、最多 [_maxImageUrlsPerTier] 筆）。
  Future<List<String>> _collectResolvableImageUrls(
    List<Map<String, dynamic>> rows,
  ) async {
    final out = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final url = await _resolveImageUrl(row['image_url']);
      if (url != null && seen.add(url)) {
        out.add(url);
        if (out.length >= _maxImageUrlsPerTier) break;
      }
    }
    return out;
  }

  /// 同一比對層級最多保留幾個備援 URL（主 URL 載入失敗時 UI 依序嘗試）。
  static const int _maxImageUrlsPerTier = 5;

  /// 藥典列的中／英文名是否包含任一「品牌詞」。
  ///
  /// 品牌詞需夠有鑑別度：中文 ≥2 字、英文 ≥4 字（去標點後比對），避免
  /// 「錠」「mg」這類雜詞造成假吻合。
  bool _rowMatchesBrand(Map<String, dynamic> row, Set<String> brandTerms) {
    if (brandTerms.isEmpty) return false;
    final zh = _normalizeForSubstringMatch(row['name_zh']?.toString() ?? '');
    final en = _normalizeForSubstringMatch(row['name_en']?.toString() ?? '');
    if (zh.isEmpty && en.isEmpty) return false;

    for (final bt in brandTerms) {
      final isCjk = _containsCjk(bt);
      if (isCjk) {
        if (bt.length < 2) continue;
      } else {
        if (bt.length < 4) continue;
      }
      if ((zh.isNotEmpty && zh.contains(bt)) ||
          (en.isNotEmpty && en.contains(bt))) {
        return true;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _forwardSearch(Set<String> terms) async {
    final safeTerms = terms
        .map(_sanitizeOrTerm)
        .where((t) => t.isNotEmpty)
        .toSet();
    if (safeTerms.isEmpty) return const [];

    // PostgREST `.or()` 語法：`col.op.value,col.op.value,...`，ilike 的萬用字元
    // 在這裡要用 `*`（HTTP 端會被轉成 `%`）。
    final orParts = <String>[];
    for (final t in safeTerms) {
      orParts.add('name_zh.ilike.*$t*');
      orParts.add('name_en.ilike.*$t*');
    }

    try {
      final rows = await _client
          .from('drug_dictionary')
          .select('image_url, name_zh, name_en')
          .or(orParts.join(','))
          .limit(20);

      final list = (rows as List)
          .cast<Object?>()
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (list.isEmpty) return const [];

      // 若多筆命中，挑「藥典名最短」者優先；解析圖片時仍會依序嘗試每列。
      _sortRowsForImagePick(list);
      return list;
    } catch (e) {
      print('[DrugDictionary] _forwardSearch error: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _reverseSearch(
    List<String> candidates,
  ) async {
    final normalizedCandidates = candidates
        .map(_normalizeForSubstringMatch)
        .where((c) => c.length >= 2)
        .toList();
    if (normalizedCandidates.isEmpty) return const [];

    try {
      final rows = await _client
          .from('drug_dictionary')
          .select('image_url, name_zh, name_en')
          .limit(_reverseSearchLimit);

      final matches = <Map<String, dynamic>>[];
      final seenRowKeys = <String>{};
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final rowKey =
            '${map['name_zh']}|${map['name_en']}|${map['image_url']}';
        if (!seenRowKeys.add(rowKey)) continue;
        for (final key in const ['name_zh', 'name_en']) {
          final dictName = map[key]?.toString().trim() ?? '';
          if (dictName.length < 2) continue;
          final normalizedDict = _normalizeForSubstringMatch(dictName);
          for (final cand in normalizedCandidates) {
            if (cand.contains(normalizedDict) ||
                normalizedDict.contains(cand)) {
              matches.add(map);
              break;
            }
          }
        }
      }

      _sortRowsForImagePick(matches);
      return matches;
    } catch (e) {
      print('[DrugDictionary] _reverseSearch error: $e');
      return const [];
    }
  }

  /// 子字串比對前去掉空白與標點，避免 `雅脈(Olmesartan)` 對不到 `Olmesartan`。
  static String _normalizeForSubstringMatch(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[\s,，、+/／()（）."\\\u0027-]+'), '');
  }

  int _shorterName(Map<String, dynamic> row) {
    final zh = row['name_zh']?.toString().trim() ?? '';
    final en = row['name_en']?.toString().trim() ?? '';
    final candidates = [zh, en].where((s) => s.isNotEmpty);
    if (candidates.isEmpty) return 999;
    return candidates.map((s) => s.length).reduce((a, b) => a < b ? a : b);
  }

  /// 已鏡像到 Supabase Storage 的 `image_url`（`drug-images/...`）優先於外部
  /// 連結，避免 generic fallback 先命中 404/403 的外部圖床而顯示破圖。
  static bool _isMirroredStorageUrl(Object? raw) {
    final v = raw?.toString().trim() ?? '';
    return v.startsWith('drug-images/');
  }

  void _sortRowsForImagePick(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
      final aMirrored = _isMirroredStorageUrl(a['image_url']);
      final bMirrored = _isMirroredStorageUrl(b['image_url']);
      if (aMirrored != bMirrored) return aMirrored ? -1 : 1;
      return _shorterName(a).compareTo(_shorterName(b));
    });
  }

  /// PostgREST `.or()` 值不允許 `, ( ) . " '`；同時清掉 `\` 避免被當逃脫字元。
  /// 這些字元也不該出現在合理藥名裡，直接濾掉風險最低。
  static String _sanitizeOrTerm(String raw) {
    return raw
        .replaceAll(RegExp(r'[,()."\\\u0027]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 把 `drug_dictionary.image_url` 欄位轉成實際可用的圖片網址。
  ///
  /// 支援三種寫法：
  /// 1. `https://...` / `http://...` → 直接使用。
  /// 2. `bucket/path/to.jpg` → 用對應 bucket 取 public URL。
  /// 3. 只有檔名 → 依序到 [_candidateBuckets] 查實際是否存在。
  Future<String?> _resolveImageUrl(Object? raw) async {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return normalizeExternalImageUrl(value);
    }

    if (value.contains('/')) {
      final slash = value.indexOf('/');
      final bucket = value.substring(0, slash);
      final objectPath = value.substring(slash + 1);
      if (objectPath.isNotEmpty) {
        return _resolveStorageObjectUrl(
          bucket: bucket,
          objectPath: objectPath,
          skipExistsCheck: true,
        );
      }
    }

    for (final bucket in _candidateBuckets) {
      final url = await _resolveStorageObjectUrl(
        bucket: bucket,
        objectPath: value,
      );
      if (url != null) return url;
    }

    print(
      '[DrugDictionary] image "$value" not found in any candidate bucket: '
      '$_candidateBuckets',
    );
    return null;
  }

  /// Private bucket 需 signed URL；public bucket 則 signed / public 皆可。
  Future<String?> _resolveStorageObjectUrl({
    required String bucket,
    required String objectPath,
    bool skipExistsCheck = false,
  }) async {
    if (!skipExistsCheck &&
        !await _objectExistsInBucket(bucket: bucket, filename: objectPath)) {
      return null;
    }

    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(objectPath, _signedUrlTtlSeconds);
    } catch (e) {
      print('[DrugDictionary] signedUrl($bucket/$objectPath) failed: $e');
    }

    try {
      return _client.storage.from(bucket).getPublicUrl(objectPath);
    } catch (e) {
      print('[DrugDictionary] publicUrl($bucket/$objectPath) failed: $e');
    }
    return null;
  }

  /// 用 Storage list API 檢查指定 bucket 是否存有此檔（精確或子路徑檔名比對）。
  Future<bool> _objectExistsInBucket({
    required String bucket,
    required String filename,
  }) async {
    try {
      final baseName = filename.contains('/')
          ? filename.substring(filename.lastIndexOf('/') + 1)
          : filename;
      final files = await _client.storage.from(bucket).list(
            searchOptions: SearchOptions(search: baseName, limit: 10),
          );
      return files.any(
        (f) =>
            f.name == baseName ||
            f.name == filename ||
            filename.endsWith('/${f.name}'),
      );
    } catch (e) {
      print('[DrugDictionary] list($bucket) failed: $e');
      return false;
    }
  }
}

/// 修正藥典外部圖床常見 URL 瑕疵（反斜線、空白、protocol 後多斜線）。
String normalizeExternalImageUrl(String raw) {
  var url = raw.trim().replaceAll('\\', '/');
  url = url.replaceAll(RegExp(r'\s+'), '');
  // `http://host//path` → `http://host/path`
  url = url.replaceFirstMapped(
    RegExp(r'^(https?:)//+([^/])'),
    (m) => '${m.group(1)}//${m.group(2)}',
  );
  try {
    final uri = Uri.parse(url);
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.toString();
    }
  } catch (_) {}
  return url;
}

/// 複方學名展開：整串 + 各成分（如 "Pioglitazone Metformin" → 兩個成分詞）。
List<String> expandGenericNameSearchTerms(String raw) {
  final result = <String>{};
  result.addAll(expandDrugLookupSearchTerms(raw));
  for (final part in raw.split(RegExp(r'[\s+／/、,，]+'))) {
    final p = part.trim();
    if (p.length >= 4) result.add(p);
  }
  return result.toList();
}

/// 由原始藥名展開出搜尋字：含原文、去劑量、括號內外切詞。
///
/// 匯出供單元測試；[DrugDictionaryService] 內部查詢亦使用此函式。
List<String> expandDrugLookupSearchTerms(String raw) {
  final result = <String>{};
  final name = raw.trim();
  if (name.isEmpty) return result.toList();

  void addTerm(String t) {
    final clean = t.trim();
    if (clean.isEmpty) return;
    final minLen = _containsCjk(clean)
        ? DrugDictionaryService._minCjkTermLength
        : DrugDictionaryService._minLatinTermLength;
    if (clean.length < minLen) return;
    if (DrugDictionaryService._stopTerms.contains(clean.toLowerCase())) {
      return;
    }
    if (RegExp(r'^\d+(\.\d+)?(mg|ml|mcg|μg)$', caseSensitive: false)
        .hasMatch(clean)) {
      return;
    }
    result.add(clean);
  }

  addTerm(name);

  final withoutDose = name
      .replaceAll(
        RegExp(
          r'[\d.]+\s*(?:mg|ml|公克|毫克|mcg|μg)|[\d.]+(?:mg|ml|mcg|μg)',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (withoutDose != name) addTerm(withoutDose);

  final splitPattern = RegExp(r'[\s、,，+/／()（）]+');
  for (final part in name.split(splitPattern)) {
    addTerm(part);
  }

  return result.toList();
}

bool _containsCjk(String text) {
  return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
}

/// 從處方紀錄組出藥典查詢候選藥名（去重、排除占位字）。
List<String> buildDrugLookupCandidates({
  String? medicationName,
  List<Map<String, dynamic>> medicationsDetail = const [],
}) {
  final out = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return;
    if (t == kMedicationNamePlaceholder) return;
    if (seen.add(t)) out.add(t);
  }

  for (final med in medicationsDetail) {
    add(med['name']?.toString());
  }

  add(medicationName);
  if (medicationName != kMedicationNamePlaceholder) {
    for (final part
        in (medicationName ?? '').split(RegExp(r'[、,，/／()（）]+'))) {
      add(part);
    }
  }

  return out;
}

/// 從處方的 `medications_detail` 取出藥品學名（英文成分名）清單。
///
/// 供藥典比對的「弱詞」放寬召回用（不能單獨成立比對）。只有新版掃描寫入的
/// 列才有 `genericName` 欄位；舊資料回空清單，比對自動退化成寬鬆模式。
List<String> buildDrugLookupGenericNames(
  List<Map<String, dynamic>> medicationsDetail,
) {
  final out = <String>[];
  final seen = <String>{};
  for (final med in medicationsDetail) {
    final g = med['genericName']?.toString().trim() ?? '';
    if (g.isEmpty) continue;
    if (seen.add(g.toLowerCase())) out.add(g);
  }
  return out;
}

/// 從處方紀錄取出用於藥典查詢的主要藥名（多藥時取第一項）。
String primaryDrugNameForLookup(String? displayMedicationName) {
  final candidates = buildDrugLookupCandidates(
    medicationName: displayMedicationName,
  );
  return candidates.isNotEmpty ? candidates.first : '';
}
