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
class DrugImageMatched extends DrugImageLookup {
  const DrugImageMatched(this.imageUrl);
  final String imageUrl;
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

  /// 單次查詢的總 timeout：包含 PostgREST 查藥典 + Storage list 驗證。
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

  /// 搜尋字最小長度（含中文）。`mg`、`錠` 等 2 個字以下太短，誤命中率高。
  static const int _minTermLength = 3;

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
  Future<DrugImageLookup> fetchDrugImageForCandidates(
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return const DrugImageNotFound();

    final cacheKey = _cacheKey(candidates);
    final cached = _imageUrlCache[cacheKey];
    if (cached != null) {
      print('[DrugDictionary] cache hit "$cacheKey"');
      return cached;
    }

    try {
      final url = await _fetchImageForCandidates(candidates)
          .timeout(_queryTimeout);
      final result = url == null
          ? const DrugImageNotFound()
          : DrugImageMatched(url);
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

  String _cacheKey(List<String> candidates) {
    final cleaned = candidates
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList()
      ..sort();
    return cleaned.join('|');
  }

  Future<String?> _fetchImageForCandidates(List<String> candidates) async {
    final terms = <String>{};
    for (final raw in candidates) {
      terms.addAll(_searchTerms(raw));
    }

    // 1) Forward：把所有 term × name_zh/name_en 並列成一個 .or() 一次打。
    final forward = await _forwardSearch(terms);
    if (forward != null) {
      return _resolveImageUrl(forward['image_url']);
    }

    // 2) Reverse：「藥典名」是處方藥名的子字串（例如處方寫
    //    「ATORVASTATIN 20mg」、藥典存「Atorvastatin」），這只能 client-side
    //    比對，但限制取樣 500 筆避免拖垮網路。
    final reverse = await _reverseSearch(candidates);
    if (reverse != null) {
      return _resolveImageUrl(reverse['image_url']);
    }

    print('[DrugDictionary] no dictionary entry matched: $candidates');
    return null;
  }

  Future<Map<String, dynamic>?> _forwardSearch(Set<String> terms) async {
    final safeTerms = terms
        .map(_sanitizeOrTerm)
        .where((t) => t.isNotEmpty)
        .toSet();
    if (safeTerms.isEmpty) return null;

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
      if (list.isEmpty) return null;

      // 若多筆命中，挑「藥典名最短」者；通常代表更精確（避免把通用詞撈來）。
      list.sort((a, b) {
        final la = _shorterName(a);
        final lb = _shorterName(b);
        return la.compareTo(lb);
      });
      return list.first;
    } catch (e) {
      print('[DrugDictionary] _forwardSearch error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _reverseSearch(List<String> candidates) async {
    final lowerCandidates = candidates
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList();
    if (lowerCandidates.isEmpty) return null;

    try {
      final rows = await _client
          .from('drug_dictionary')
          .select('image_url, name_zh, name_en')
          .limit(_reverseSearchLimit);

      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        for (final key in const ['name_zh', 'name_en']) {
          final dictName = map[key]?.toString().trim() ?? '';
          if (dictName.length < 2) continue;
          final lowerDict = dictName.toLowerCase();
          for (final cand in lowerCandidates) {
            if (cand.contains(lowerDict) || lowerDict.contains(cand)) {
              return map;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('[DrugDictionary] _reverseSearch error: $e');
      return null;
    }
  }

  int _shorterName(Map<String, dynamic> row) {
    final zh = row['name_zh']?.toString().trim() ?? '';
    final en = row['name_en']?.toString().trim() ?? '';
    final candidates = [zh, en].where((s) => s.isNotEmpty);
    if (candidates.isEmpty) return 999;
    return candidates.map((s) => s.length).reduce((a, b) => a < b ? a : b);
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
      return value;
    }

    if (value.contains('/')) {
      final slash = value.indexOf('/');
      final bucket = value.substring(0, slash);
      final objectPath = value.substring(slash + 1);
      if (objectPath.isNotEmpty) {
        return _client.storage.from(bucket).getPublicUrl(objectPath);
      }
    }

    for (final bucket in _candidateBuckets) {
      if (await _objectExistsInBucket(bucket: bucket, filename: value)) {
        return _client.storage.from(bucket).getPublicUrl(value);
      }
    }

    print(
      '[DrugDictionary] image "$value" not found in any candidate bucket: '
      '$_candidateBuckets',
    );
    return null;
  }

  /// 用 Storage list API 檢查指定 bucket 是否存有此檔（**精確檔名**比對）。
  Future<bool> _objectExistsInBucket({
    required String bucket,
    required String filename,
  }) async {
    try {
      final files = await _client.storage.from(bucket).list(
            searchOptions: SearchOptions(search: filename, limit: 5),
          );
      return files.any((f) => f.name == filename);
    } catch (e) {
      print('[DrugDictionary] list($bucket) failed: $e');
      return false;
    }
  }

  /// 由原始藥名展開出搜尋字：含原文、去劑量單位後的精簡名、空格／符號切詞。
  ///
  /// **品質控管**：
  /// - 長度 < [_minTermLength] 直接丟（`mg`、`錠` 等噪音）
  /// - 命中 [_stopTerms] 黑名單也丟
  ///
  /// 之前沒這層過濾時，英文藥名常切出 `tablets`、`mg`，被當搜尋詞後會誤命中
  /// 其他剛好有「tablets」在中文／英文 column 的列。
  static List<String> _searchTerms(String raw) {
    final result = <String>{};
    final name = raw.trim();
    if (name.isEmpty) return result.toList();

    void addTerm(String t) {
      final clean = t.trim();
      if (clean.isEmpty) return;
      // 中文以「字」算長度，英文以字元算；length 對 UTF-16 已夠用。
      if (clean.length < _minTermLength) return;
      if (_stopTerms.contains(clean.toLowerCase())) return;
      result.add(clean);
    }

    addTerm(name);

    final withoutDose = name
        .replaceAll(
          RegExp(r'[\d.]+\s*(mg|ml|公克|毫克|mcg|μg)?', caseSensitive: false),
          '',
        )
        .trim();
    if (withoutDose != name) addTerm(withoutDose);

    for (final part in name.split(RegExp(r'[\s、,，+/／]+'))) {
      addTerm(part);
    }

    return result.toList();
  }
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
  for (final part in (medicationName ?? '').split(RegExp(r'[、,，/／]'))) {
    add(part);
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
