import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';
import 'package:smart_bp/features/shop/data/shop_category_images.dart';

/// 長輩代購常用物資模板（Dart 本地常數，不寫 DB）。
final class SupplyBrandOption {
  const SupplyBrandOption({
    required this.id,
    required this.brand,
    required this.displayName,
    required this.spec,
    required this.unitLabel,
    this.refPrice,
    this.imageUrl,
    this.pxSearchKeyword,
    this.sourceUrl,
    this.isUnspecified = false,
    this.isOther = false,
  });

  final String id;
  final String brand;
  final String displayName;
  final String spec;
  final String unitLabel;
  final double? refPrice;
  final String? imageUrl;
  final String? pxSearchKeyword;
  final String? sourceUrl;

  /// 無指定品牌（志工代選）。
  final bool isUnspecified;
  final bool isOther;

  String get templateProductId => 'tpl:$id';
}

final class SupplyCategory {
  const SupplyCategory({
    required this.key,
    required this.label,
    required this.keywords,
    required this.options,
    this.defaultUnitLabel = '包',
    this.categoryImageCategory,
  });

  final String key;
  final String label;
  final List<String> keywords;
  final List<SupplyBrandOption> options;
  final String defaultUnitLabel;
  final String? categoryImageCategory;

  String? get categoryImageUrl =>
      ShopCategoryImages.urlForCategory(categoryImageCategory ?? label);
}

abstract final class ElderSupplyTemplates {
  static const _tissueIcon =
      'https://cdn-icons-png.flaticon.com/128/2910/2910913.png';
  static const _eggIcon =
      'https://cdn-icons-png.flaticon.com/128/2674/2674464.png';
  static const _milkIcon =
      'https://cdn-icons-png.flaticon.com/128/3529/3529367.png';
  static const _riceIcon =
      'https://cdn-icons-png.flaticon.com/128/2927/2927347.png';
  static const _detergentIcon =
      'https://cdn-icons-png.flaticon.com/128/2920/2920277.png';
  static const _diaperIcon =
      'https://cdn-icons-png.flaticon.com/128/2913/2913145.png';

  static const unspecifiedBrandLabel = '無指定品牌';

  static const categories = <SupplyCategory>[
    SupplyCategory(
      key: 'tissue',
      label: '衛生紙',
      keywords: ['衛生紙', '面紙', '紙巾', '抽取式'],
      defaultUnitLabel: '提',
      categoryImageCategory: '清潔用品',
      options: [
        SupplyBrandOption(
          id: 'tissue:scott',
          brand: '舒潔',
          displayName: '舒潔抽取式衛生紙',
          spec: '100抽×10包',
          unitLabel: '提',
          refPrice: 199,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '舒潔抽取式衛生紙',
        ),
        SupplyBrandOption(
          id: 'tissue:mayflower',
          brand: '五月花',
          displayName: '五月花抽取式衛生紙',
          spec: '100抽×10包',
          unitLabel: '提',
          refPrice: 189,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '五月花抽取式衛生紙',
        ),
        SupplyBrandOption(
          id: 'tissue:deyi',
          brand: '得意',
          displayName: '得意抽取式衛生紙',
          spec: '100抽×10包',
          unitLabel: '提',
          refPrice: 169,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '得意抽取式衛生紙',
        ),
        SupplyBrandOption(
          id: 'tissue:any',
          brand: unspecifiedBrandLabel,
          displayName: '衛生紙（無指定品牌）',
          spec: '志工代選',
          unitLabel: '提',
          isUnspecified: true,
          imageUrl: _tissueIcon,
        ),
        SupplyBrandOption(
          id: 'tissue:other',
          brand: '其他',
          displayName: '其他品牌衛生紙',
          spec: '請於備註說明',
          unitLabel: '提',
          isOther: true,
          imageUrl: _tissueIcon,
        ),
      ],
    ),
    SupplyCategory(
      key: 'egg',
      label: '雞蛋',
      keywords: ['雞蛋', '蛋'],
      defaultUnitLabel: '盒',
      categoryImageCategory: '雞蛋相關',
      options: [
        SupplyBrandOption(
          id: 'egg:fresh',
          brand: '洗選鮮蛋',
          displayName: '洗選鮮蛋',
          spec: '10入/盒',
          unitLabel: '盒',
          refPrice: 89,
          imageUrl: _eggIcon,
          pxSearchKeyword: '洗選鮮蛋10入',
        ),
        SupplyBrandOption(
          id: 'egg:country',
          brand: '鄉牧',
          displayName: '鄉牧鮮蛋',
          spec: '10入/盒',
          unitLabel: '盒',
          refPrice: 95,
          imageUrl: _eggIcon,
          pxSearchKeyword: '鄉牧鮮蛋',
        ),
        SupplyBrandOption(
          id: 'egg:any',
          brand: unspecifiedBrandLabel,
          displayName: '雞蛋（無指定品牌）',
          spec: '志工代選',
          unitLabel: '盒',
          isUnspecified: true,
          imageUrl: _eggIcon,
        ),
        SupplyBrandOption(
          id: 'egg:other',
          brand: '其他',
          displayName: '其他雞蛋',
          spec: '請於備註說明',
          unitLabel: '盒',
          isOther: true,
          imageUrl: _eggIcon,
        ),
      ],
    ),
    SupplyCategory(
      key: 'milk',
      label: '鮮奶',
      keywords: ['鮮奶', '牛奶', '牛乳'],
      defaultUnitLabel: '瓶',
      categoryImageCategory: '營養補給',
      options: [
        SupplyBrandOption(
          id: 'milk:linfeng',
          brand: '林鳳營',
          displayName: '林鳳營鮮奶',
          spec: '936ml',
          unitLabel: '瓶',
          refPrice: 89,
          imageUrl: _milkIcon,
          pxSearchKeyword: '林鳳營鮮奶',
        ),
        SupplyBrandOption(
          id: 'milk:guangming',
          brand: '光泉',
          displayName: '光泉鮮奶',
          spec: '936ml',
          unitLabel: '瓶',
          refPrice: 85,
          imageUrl: _milkIcon,
          pxSearchKeyword: '光泉鮮奶',
        ),
        SupplyBrandOption(
          id: 'milk:ruisui',
          brand: '瑞穗',
          displayName: '瑞穗鮮乳',
          spec: '936ml',
          unitLabel: '瓶',
          refPrice: 82,
          imageUrl: _milkIcon,
          pxSearchKeyword: '瑞穗鮮乳',
        ),
        SupplyBrandOption(
          id: 'milk:any',
          brand: unspecifiedBrandLabel,
          displayName: '鮮奶（無指定品牌）',
          spec: '志工代選',
          unitLabel: '瓶',
          isUnspecified: true,
          imageUrl: _milkIcon,
        ),
        SupplyBrandOption(
          id: 'milk:other',
          brand: '其他',
          displayName: '其他鮮奶',
          spec: '請於備註說明',
          unitLabel: '瓶',
          isOther: true,
          imageUrl: _milkIcon,
        ),
      ],
    ),
    SupplyCategory(
      key: 'rice',
      label: '白米',
      keywords: ['白米', '米', '米飯'],
      defaultUnitLabel: '包',
      categoryImageCategory: '米糧',
      options: [
        SupplyBrandOption(
          id: 'rice:taitung5',
          brand: '台東5號',
          displayName: '台東5號米',
          spec: '3kg',
          unitLabel: '包',
          refPrice: 199,
          imageUrl: _riceIcon,
          pxSearchKeyword: '台東5號米3kg',
        ),
        SupplyBrandOption(
          id: 'rice:formosa',
          brand: '福壽',
          displayName: '福壽米',
          spec: '3kg',
          unitLabel: '包',
          refPrice: 189,
          imageUrl: _riceIcon,
          pxSearchKeyword: '福壽米3kg',
        ),
        SupplyBrandOption(
          id: 'rice:any',
          brand: unspecifiedBrandLabel,
          displayName: '白米（無指定品牌）',
          spec: '志工代選',
          unitLabel: '包',
          isUnspecified: true,
          imageUrl: _riceIcon,
        ),
        SupplyBrandOption(
          id: 'rice:other',
          brand: '其他',
          displayName: '其他白米',
          spec: '請於備註說明',
          unitLabel: '包',
          isOther: true,
          imageUrl: _riceIcon,
        ),
      ],
    ),
    SupplyCategory(
      key: 'detergent',
      label: '洗衣精',
      keywords: ['洗衣精', '洗衣液', '洗衣劑'],
      defaultUnitLabel: '瓶',
      categoryImageCategory: '清潔用品',
      options: [
        SupplyBrandOption(
          id: 'detergent:blanc',
          brand: '白蘭',
          displayName: '白蘭超濃縮洗衣精',
          spec: '2.7kg',
          unitLabel: '瓶',
          refPrice: 199,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '白蘭超濃縮洗衣精',
        ),
        SupplyBrandOption(
          id: 'detergent:attack',
          brand: '一匙靈',
          displayName: '一匙靈抗菌EX洗衣精',
          spec: '2.4kg',
          unitLabel: '瓶',
          refPrice: 219,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '一匙靈抗菌EX洗衣精',
        ),
        SupplyBrandOption(
          id: 'detergent:maobao',
          brand: '毛寶',
          displayName: '毛寶全效抗菌洗衣精',
          spec: '3.5kg',
          unitLabel: '瓶',
          refPrice: 189,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '毛寶全效抗菌洗衣精',
        ),
        SupplyBrandOption(
          id: 'detergent:any',
          brand: unspecifiedBrandLabel,
          displayName: '洗衣精（無指定品牌）',
          spec: '志工代選',
          unitLabel: '瓶',
          isUnspecified: true,
          imageUrl: _detergentIcon,
        ),
        SupplyBrandOption(
          id: 'detergent:other',
          brand: '其他',
          displayName: '其他洗衣精',
          spec: '請於備註說明',
          unitLabel: '瓶',
          isOther: true,
          imageUrl: _detergentIcon,
        ),
      ],
    ),
    SupplyCategory(
      key: 'diaper',
      label: '成人尿布',
      keywords: ['成人尿布', '尿布', '尿片', '看護墊'],
      defaultUnitLabel: '包',
      categoryImageCategory: '清潔用品',
      options: [
        SupplyBrandOption(
          id: 'diaper:tena',
          brand: '添寧',
          displayName: '添寧成人紙尿褲',
          spec: 'M號 10片',
          unitLabel: '包',
          refPrice: 299,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '添寧成人紙尿褲',
        ),
        SupplyBrandOption(
          id: 'diaper:lifree',
          brand: '來復易',
          displayName: '來復易黏貼式紙尿片',
          spec: '10片',
          unitLabel: '包',
          refPrice: 279,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '來復易黏貼式紙尿片',
        ),
        SupplyBrandOption(
          id: 'diaper:drp',
          brand: '包大人',
          displayName: '包大人成人紙尿褲',
          spec: 'M號 10片',
          unitLabel: '包',
          refPrice: 289,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '包大人成人紙尿褲',
        ),
        SupplyBrandOption(
          id: 'diaper:any',
          brand: unspecifiedBrandLabel,
          displayName: '成人尿布（無指定品牌）',
          spec: '志工代選',
          unitLabel: '包',
          isUnspecified: true,
          imageUrl: _diaperIcon,
        ),
        SupplyBrandOption(
          id: 'diaper:other',
          brand: '其他',
          displayName: '其他成人尿布',
          spec: '請於備註說明',
          unitLabel: '包',
          isOther: true,
          imageUrl: _diaperIcon,
        ),
      ],
    ),
  ];

  static SupplyCategory? findCategoryByKeyword(String keyword) {
    final n = keyword.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (n.isEmpty) return null;
    SupplyCategory? best;
    var bestLen = 0;
    for (final c in categories) {
      for (final k in c.keywords) {
        final kn = k.toLowerCase();
        if (n.contains(kn) || kn.contains(n)) {
          if (kn.length > bestLen) {
            bestLen = kn.length;
            best = c;
          }
        }
      }
    }
    return best;
  }

  static SupplyCategory? findCategoryByKey(String key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }

  static SupplyBrandOption? findOption(SupplyCategory cat, String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(t)) {
      final idx = int.parse(t) - 1;
      if (idx >= 0 && idx < cat.options.length) return cat.options[idx];
    }
    final lower = t.toLowerCase();
    for (final o in cat.options) {
      if (o.brand == t ||
          o.displayName.contains(t) ||
          t.contains(o.brand) ||
          (o.isUnspecified &&
              (t.contains('無指定') || t.contains('都可以') || t == '都可以'))) {
        return o;
      }
      if (lower == o.id.split(':').last) return o;
    }
    return null;
  }

  static SupplyLineSnapshot buildSnapshot({
    required SupplyCategory category,
    required SupplyBrandOption option,
    required int quantity,
    String? unitLabel,
    String? referenceNote,
  }) {
    final unit = unitLabel ?? option.unitLabel;
    final note = option.isOther
        ? (referenceNote ?? '長輩指定其他品牌')
        : option.isUnspecified
            ? '志工代選品牌'
            : referenceNote;
    return SupplyLineSnapshot(
      productId: 'tpl:${category.key}:${option.id.split(':').last}',
      productName: option.isUnspecified
          ? '${category.label}（$unspecifiedBrandLabel）'
          : option.displayName,
      quantity: quantity,
      unitPrice: option.refPrice,
      brand: option.brand,
      spec: option.spec,
      unitLabel: unit,
      category: category.label,
      supplyCategoryKey: category.key,
      templateOptionId: option.id,
      pxSearchKeyword: option.pxSearchKeyword,
      sourceUrl: option.sourceUrl,
      imageUrl: option.imageUrl ?? category.categoryImageUrl,
      referenceNote: note,
    );
  }

  static bool lineNeedsBrand(String productName) {
    final cat = findCategoryByKeyword(productName);
    return cat != null;
  }

  static bool isBareCategoryLine(String productName) {
    final cat = findCategoryByKeyword(productName);
    if (cat == null) return false;
    final n = productName.trim();
    for (final k in cat.keywords) {
      if (n == k || n == cat.label) return true;
    }
    return n.length <= 8 && cat.keywords.any((k) => n.contains(k));
  }
}
