import 'dart:convert';

/// Comet／人工整理之「柑仔店」參考商品（價格僅供展示，以實際通路為準）。
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    this.spec,
    required this.category,
    this.unitPrice,
    this.unitLabel,
    this.originalPrice,
    this.promoText,
    this.sourceUrl,
    this.fetchedAt,
    this.notes,
    this.confidence,
    this.imageUrl,
    this.productId,
    this.backupSearchKeyword,
  });

  final String id;
  final String name;
  final String? spec;
  final String category;
  final double? unitPrice;
  final String? unitLabel;
  final double? originalPrice;
  final String? promoText;
  final String? sourceUrl;
  final String? fetchedAt;
  final String? notes;
  final String? confidence;
  final String? imageUrl;
  final String? productId;
  final String? backupSearchKeyword;

  /// 與「全聯搜尋」按鈕相同：品牌／備援關鍵字／規格（較完整，方便對應促銷組與連結）。
  String get pxMartSearchKeyword {
    final fromSeed = backupSearchKeyword?.trim();
    final n = name.trim();
    final sp = spec?.trim() ?? '';
    final brand = RegExp(r'【([^】]+)】').firstMatch(n)?.group(1)?.trim() ?? '';
    final parts = <String>[
      if (brand.isNotEmpty) brand,
      if (fromSeed != null && fromSeed.isNotEmpty) fromSeed,
      if (sp.isNotEmpty) sp,
    ];
    if (parts.isEmpty) return n;
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 給全聯「搜尋縮圖」用：弱化容量、包數、價格與促銷字眼，較接近單品主圖。
  /// （對外開啟全聯仍用 [pxMartSearchKeyword]。）
  String get pxMartImageSearchKeyword {
    final n = name.trim();
    final brand = RegExp(r'【([^】]+)】').firstMatch(n)?.group(1)?.trim() ?? '';
    final fromSeed = backupSearchKeyword?.trim();

    var titleNoBracket = n.replaceAll(RegExp(r'【[^】]*】'), ' ');
    titleNoBracket = ShopProduct._stripPromoAndPackagingForImageSearch(titleNoBracket);

    final seedClean = fromSeed != null && fromSeed.isNotEmpty
        ? ShopProduct._stripPromoAndPackagingForImageSearch(fromSeed)
        : '';

    final parts = <String>[
      if (brand.isNotEmpty) brand,
      if (seedClean.isNotEmpty) seedClean,
      if (titleNoBracket.isNotEmpty) titleNoBracket,
    ];
    final joined = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (joined.isEmpty) return pxMartSearchKeyword;
    return joined;
  }

  static String _stripPromoAndPackagingForImageSearch(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return '';
    t = t.replaceAll(RegExp(r'[（(][^）)]*[）)]'), ' ');
    t = t.replaceAll(
      RegExp(r'箱購|首購價|折後價|售價|原價|特價|限購|組合|超值組|促銷組|預購|限時'),
      ' ',
    );
    t = t.replaceAll(RegExp(r'NT\$[\d,]+|\$\s*[\d,]+|[\$＄]\s*\d'), ' ');
    t = t.replaceAll(
      RegExp(r'\d+\.?\d*\s*[×x]\s*\d+\s*(包|入|瓶|罐|袋|組|碗|杯|箱)?', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(
      RegExp(r'\d+\s*(包|入|瓶|罐|袋|組|碗|杯|箱)(?=\s|$)', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(
      RegExp(r'\d+\.?\d*\s*(kg|g|ml|mL|ML|L)(?=\s|$|[^a-zA-Z])', caseSensitive: false),
      ' ',
    );
    t = t.replaceAll(RegExp(r'\b\d+\b'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<ShopProduct> listFromJsonString(String jsonStr) {
    final decoded = json.decode(jsonStr);
    if (decoded is! List<dynamic>) {
      throw FormatException('預期 JSON 最外層為陣列，實際為：${decoded.runtimeType}');
    }
    return decoded
        .map((e) => ShopProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 解析 Comet 常見條列格式，例如：
  /// 【品牌】品名
  /// 首購價：$1,432（原價 $1,704）
  /// 連結：https://...
  /// imgURL：https://...（可選；舊格式「圖片：」仍支援）
  static List<ShopProduct> listFromCometText(String text) {
    final blocks = text
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final items = <ShopProduct>[];
    for (final block in blocks) {
      final item = _fromCometBlock(block);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  /// 複製並覆寫欄位（例如載入後套用爬蟲圖網址）。
  ShopProduct copyWith({
    String? imageUrl,
  }) {
    return ShopProduct(
      id: id,
      name: name,
      spec: spec,
      category: category,
      unitPrice: unitPrice,
      unitLabel: unitLabel,
      originalPrice: originalPrice,
      promoText: promoText,
      sourceUrl: sourceUrl,
      fetchedAt: fetchedAt,
      notes: notes,
      confidence: confidence,
      imageUrl: imageUrl ?? this.imageUrl,
      productId: productId,
      backupSearchKeyword: backupSearchKeyword,
    );
  }

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      id: _firstString(json, const ['id', '編號', 'sku', 'productId']) ?? _fallbackId(json),
      name: _firstString(json, const ['name', '品名', 'title', '商品名稱']) ?? '未命名商品',
      spec: _firstString(json, const ['spec', '規格', 'package']),
      category: _firstString(json, const ['category', '分類', '類別']) ?? '其他',
      unitPrice: _firstPrice(json, const ['unitPrice', 'price', '單價', '價格', '售價']),
      unitLabel: _firstString(json, const ['unitLabel', '單位', '計價單位']),
      originalPrice: _firstPrice(json, const ['originalPrice', '原價', '定價']),
      promoText: _firstString(json, const ['promoText', '促銷', '促銷文案', '備註促銷']),
      sourceUrl: _firstString(json, const ['sourceUrl', 'url', '連結', '來源', '商品頁']),
      fetchedAt: _firstString(json, const ['fetchedAt', '更新時間', '查詢時間']),
      notes: _firstString(json, const ['notes', '備註', '說明']),
      confidence: _firstString(json, const ['confidence', '可信度']),
      imageUrl: _firstString(
        json,
        const ['imageUrl', 'imgURL', 'imgUrl', 'image', '圖片', '圖片網址'],
      ),
      productId: _firstString(json, const ['productId', '商品ID']),
      backupSearchKeyword: _firstString(json, const ['backupSearchKeyword', '備援搜尋關鍵字']),
    );
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  static double? _firstPrice(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final p = _parsePrice(json[k]);
      if (p != null) return p;
    }
    return null;
  }

  static double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned = value
        .toString()
        .replaceAll(RegExp(r'[,\s]'), '')
        .replaceAll(RegExp(r'NT\$?|元|\$'), '');
    return double.tryParse(cleaned);
  }

  static String _fallbackId(Map<String, dynamic> json) {
    final name = _firstString(json, const ['name', '品名', 'title']) ?? 'item';
    final spec = _firstString(json, const ['spec', '規格']) ?? '';
    return '${name}_$spec'.hashCode.abs().toString();
  }

  static ShopProduct? _fromCometBlock(String block) {
    final lines = block
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final titleLine = lines.first;
    if (_shouldSkipTitleLine(titleLine)) return null;
    final linkLine = lines.firstWhere(
      (line) =>
          (line.contains('連結') || line.toLowerCase().contains('link')) &&
          (line.contains('http://') || line.contains('https://')),
      orElse: () => lines.firstWhere(
        (line) =>
            (line.contains('http://') || line.contains('https://')) &&
            line.contains('/product/'),
        orElse: () => '',
      ),
    );
    final priceLine = lines.firstWhere(
      (line) => line.contains('價') || line.contains('\$'),
      orElse: () => '',
    );
    final imageLine = lines.firstWhere(
      (line) {
        final lower = line.toLowerCase();
        return lower.contains('imgurl') || line.contains('圖片');
      },
      orElse: () => '',
    );

    final sourceUrl = _extractUrl(linkLine);
    final productId = _extractProductId(sourceUrl);
    final numbers = RegExp(r'\$?\s*([0-9][0-9,]*)')
        .allMatches(priceLine)
        .map((m) => _parsePrice(m.group(1)))
        .whereType<double>()
        .toList();

    final unitPrice = numbers.isNotEmpty ? numbers.first : null;
    final originalPrice = numbers.length > 1 ? numbers[1] : null;
    final specMatch = RegExp(r'(\d+\s*ml(?:\s*×\s*\d+[^)\s]*)?)', caseSensitive: false)
        .firstMatch(titleLine);
    final spec = specMatch?.group(1);
    if (unitPrice == null && sourceUrl == null) return null;

    return ShopProduct(
      id: titleLine.hashCode.abs().toString(),
      name: titleLine,
      spec: spec,
      category: _inferCategory(titleLine),
      unitPrice: unitPrice,
      unitLabel: '每組',
      originalPrice: originalPrice,
      promoText: priceLine.isEmpty ? null : priceLine,
      sourceUrl: sourceUrl,
      imageUrl: _extractUrl(imageLine),
      productId: productId,
      backupSearchKeyword: _searchKeywordFromTitle(titleLine),
      fetchedAt: DateTime.now().toIso8601String(),
      confidence: 'medium',
      notes: '由 Comet 條列文字自動解析，請下單前再次確認通路價格。',
    );
  }

  static String? _extractUrl(String value) {
    final match = RegExp(r'https?://\S+').firstMatch(value);
    return match?.group(0);
  }

  /// 全聯電商網址中的商品數字 id，例如 `…/product/7830`。
  static String? parsePxProductId(String? url) {
    if (url == null || url.isEmpty) return null;
    final match = RegExp(r'/product/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  static String? _extractProductId(String? url) => parsePxProductId(url);

  static bool _shouldSkipTitleLine(String line) {
    const badPrefixes = ['售價', '首購價', '折後價', '連結', '原價'];
    return badPrefixes.any((p) => line.startsWith(p));
  }

  static String _inferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('米') || t.contains('糙米') || t.contains('越光')) return '米糧';
    if (t.contains('雞蛋') || t.contains('蛋液') || t.contains('溏心蛋') || t.contains('蒸蛋') || t.contains('煮蛋')) {
      return '雞蛋相關';
    }
    if (t.contains('麵') || t.contains('拉麵') || t.contains('杯麵') || t.contains('炸醬')) return '泡麵/麵食';
    if (t.contains('洗衣') || t.contains('清潔')) return '清潔用品';
    if (t.contains('營養') || t.contains('奶粉') || t.contains('蛋白') || t.contains('安素')) return '營養補給';
    if (t.contains('維他命') || t.contains('葡萄糖胺') || t.contains('膠原')) return '保健用品';
    return '其他';
  }

  static String _searchKeywordFromTitle(String title) {
    var text = title;
    text = text.replaceAll(RegExp(r'【[^】]*】'), ' ');
    text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    text = text.replaceAll(RegExp(r'[-_/]'), ' ');
    text = text.replaceAll(RegExp(r'[^\u4e00-\u9fffA-Za-z0-9 ]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return title.trim();
    final parts = text.split(' ');
    return parts.take(4).join(' ');
  }
}
