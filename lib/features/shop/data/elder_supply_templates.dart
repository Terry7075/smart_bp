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
    this.isCustomCapacity = false,
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

  /// 容量步驟的「自己填」虛擬選項（僅 UI 用）。
  final bool isCustomCapacity;

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
  static const volunteerPickBrandDisplayLabel = '志工幫選';
  static const otherBrandLabel = '其他';
  static const customCapacityOptionId = '__custom_capacity__';

  /// 長輩畫面顯示用品牌名稱。
  static String displayBrandLabel(String? brand) {
    final b = brand?.trim() ?? '';
    if (b.isEmpty) return '';
    if (b == unspecifiedBrandLabel) return volunteerPickBrandDisplayLabel;
    return b;
  }

  /// 送出確認／志工摘要一行。
  static String formatDraftLineSummary({
    required String productName,
    String? brand,
    String? spec,
    required int quantity,
    String? unitLabel,
  }) {
    final b = displayBrandLabel(brand);
    final specPart = (spec ?? '').trim();
    final name = productName.trim();
    final parts = <String>[
      if (b.isNotEmpty && !name.contains(b)) b,
      name,
      if (specPart.isNotEmpty && !name.contains(specPart)) specPart,
    ];
    final line = parts.where((p) => p.isNotEmpty).join(' · ');
    final unit = (unitLabel ?? '').trim();
    return '· $line ×$quantity${unit.isNotEmpty ? unit : ''}';
  }

  static SupplyBrandOption customCapacityPicker(SupplyCategory category, String brand) {
    return SupplyBrandOption(
      id: customCapacityOptionId,
      brand: brand,
      displayName: '$brand（自訂容量）',
      spec: '請輸入容量',
      unitLabel: category.defaultUnitLabel,
      isUnspecified: brand == unspecifiedBrandLabel,
      isCustomCapacity: true,
      imageUrl: category.categoryImageUrl,
    );
  }

  static const categories = <SupplyCategory>[
    SupplyCategory(
      key: 'tissue',
      label: '衛生紙',
      keywords: ['衛生紙', '面紙', '紙巾', '抽取式'],
      defaultUnitLabel: '提',
      categoryImageCategory: '清潔用品',
      options: [
        SupplyBrandOption(
          id: 'tissue:scott:60',
          brand: '舒潔',
          displayName: '舒潔抽取式衛生紙',
          spec: '60抽×6包',
          unitLabel: '提',
          refPrice: 129,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '舒潔抽取式衛生紙60抽',
        ),
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
          id: 'tissue:mayflower:60',
          brand: '五月花',
          displayName: '五月花抽取式衛生紙',
          spec: '60抽×6包',
          unitLabel: '提',
          refPrice: 119,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '五月花抽取式衛生紙60抽',
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
          id: 'tissue:deyi:60',
          brand: '得意',
          displayName: '得意抽取式衛生紙',
          spec: '60抽×6包',
          unitLabel: '提',
          refPrice: 109,
          imageUrl: _tissueIcon,
          pxSearchKeyword: '得意抽取式衛生紙60抽',
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
          id: 'egg:fresh:6',
          brand: '洗選鮮蛋',
          displayName: '洗選鮮蛋',
          spec: '6入/盒',
          unitLabel: '盒',
          refPrice: 55,
          imageUrl: _eggIcon,
          pxSearchKeyword: '洗選鮮蛋6入',
        ),
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
          id: 'egg:country:6',
          brand: '鄉牧',
          displayName: '鄉牧鮮蛋',
          spec: '6入/盒',
          unitLabel: '盒',
          refPrice: 59,
          imageUrl: _eggIcon,
          pxSearchKeyword: '鄉牧鮮蛋6入',
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
          id: 'milk:linfeng:185',
          brand: '林鳳營',
          displayName: '林鳳營鮮奶',
          spec: '185ml',
          unitLabel: '瓶',
          refPrice: 28,
          imageUrl: _milkIcon,
          pxSearchKeyword: '林鳳營鮮奶185ml',
        ),
        SupplyBrandOption(
          id: 'milk:linfeng:936',
          brand: '林鳳營',
          displayName: '林鳳營鮮奶',
          spec: '936ml',
          unitLabel: '瓶',
          refPrice: 89,
          imageUrl: _milkIcon,
          pxSearchKeyword: '林鳳營鮮奶',
        ),
        SupplyBrandOption(
          id: 'milk:linfeng:1l',
          brand: '林鳳營',
          displayName: '林鳳營鮮奶',
          spec: '1公升',
          unitLabel: '瓶',
          refPrice: 95,
          imageUrl: _milkIcon,
          pxSearchKeyword: '林鳳營鮮奶1公升',
        ),
        SupplyBrandOption(
          id: 'milk:guangming:200',
          brand: '光泉',
          displayName: '光泉鮮奶',
          spec: '200ml',
          unitLabel: '瓶',
          refPrice: 30,
          imageUrl: _milkIcon,
          pxSearchKeyword: '光泉鮮奶200ml',
        ),
        SupplyBrandOption(
          id: 'milk:guangming:936',
          brand: '光泉',
          displayName: '光泉鮮奶',
          spec: '936ml',
          unitLabel: '瓶',
          refPrice: 85,
          imageUrl: _milkIcon,
          pxSearchKeyword: '光泉鮮奶',
        ),
        SupplyBrandOption(
          id: 'milk:ruisui:200',
          brand: '瑞穗',
          displayName: '瑞穗鮮乳',
          spec: '200ml',
          unitLabel: '瓶',
          refPrice: 28,
          imageUrl: _milkIcon,
          pxSearchKeyword: '瑞穗鮮乳200ml',
        ),
        SupplyBrandOption(
          id: 'milk:ruisui:936',
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
          id: 'rice:taitung5:15',
          brand: '台東5號',
          displayName: '台東5號米',
          spec: '1.5kg',
          unitLabel: '包',
          refPrice: 109,
          imageUrl: _riceIcon,
          pxSearchKeyword: '台東5號米1.5kg',
        ),
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
          id: 'rice:taitung5:5',
          brand: '台東5號',
          displayName: '台東5號米',
          spec: '5kg',
          unitLabel: '包',
          refPrice: 299,
          imageUrl: _riceIcon,
          pxSearchKeyword: '台東5號米5kg',
        ),
        SupplyBrandOption(
          id: 'rice:formosa:15',
          brand: '福壽',
          displayName: '福壽米',
          spec: '1.5kg',
          unitLabel: '包',
          refPrice: 99,
          imageUrl: _riceIcon,
          pxSearchKeyword: '福壽米1.5kg',
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
          id: 'detergent:blanc:16',
          brand: '白蘭',
          displayName: '白蘭超濃縮洗衣精',
          spec: '1.6kg',
          unitLabel: '瓶',
          refPrice: 139,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '白蘭超濃縮洗衣精1.6kg',
        ),
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
          id: 'detergent:attack:12',
          brand: '一匙靈',
          displayName: '一匙靈抗菌EX洗衣精',
          spec: '1.2kg',
          unitLabel: '瓶',
          refPrice: 129,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '一匙靈抗菌EX洗衣精1.2kg',
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
          id: 'detergent:maobao:2',
          brand: '毛寶',
          displayName: '毛寶全效抗菌洗衣精',
          spec: '2kg',
          unitLabel: '瓶',
          refPrice: 129,
          imageUrl: _detergentIcon,
          pxSearchKeyword: '毛寶全效抗菌洗衣精2kg',
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
          id: 'diaper:tena:m',
          brand: '添寧',
          displayName: '添寧成人紙尿褲',
          spec: 'M號 10片',
          unitLabel: '包',
          refPrice: 299,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '添寧成人紙尿褲M',
        ),
        SupplyBrandOption(
          id: 'diaper:tena:l',
          brand: '添寧',
          displayName: '添寧成人紙尿褲',
          spec: 'L號 10片',
          unitLabel: '包',
          refPrice: 309,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '添寧成人紙尿褲L',
        ),
        SupplyBrandOption(
          id: 'diaper:lifree:m',
          brand: '來復易',
          displayName: '來復易黏貼式紙尿片',
          spec: 'M號 10片',
          unitLabel: '包',
          refPrice: 279,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '來復易黏貼式紙尿片M',
        ),
        SupplyBrandOption(
          id: 'diaper:lifree:l',
          brand: '來復易',
          displayName: '來復易黏貼式紙尿片',
          spec: 'L號 10片',
          unitLabel: '包',
          refPrice: 289,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '來復易黏貼式紙尿片L',
        ),
        SupplyBrandOption(
          id: 'diaper:drp:m',
          brand: '包大人',
          displayName: '包大人成人紙尿褲',
          spec: 'M號 10片',
          unitLabel: '包',
          refPrice: 289,
          imageUrl: _diaperIcon,
          pxSearchKeyword: '包大人成人紙尿褲M',
        ),
        SupplyBrandOption(
          id: 'diaper:drp:l',
          brand: '包大人',
          displayName: '包大人成人紙尿褲',
          spec: 'L號 10片',
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
    String? specOverride,
    String? brandOverride,
  }) {
    final unit = unitLabel ?? option.unitLabel;
    final spec = (specOverride?.trim().isNotEmpty == true)
        ? specOverride!.trim()
        : option.spec;
    final effectiveBrand = (brandOverride?.trim().isNotEmpty == true)
        ? brandOverride!.trim()
        : option.brand;
    final note = (brandOverride?.trim().isNotEmpty == true)
        ? '長輩指定品牌：${brandOverride!.trim()}，容量：$spec'
        : option.isOther
            ? (referenceNote ?? '長輩指定其他品牌')
            : option.isUnspecified
                ? '志工代選品牌，長輩指定容量：$spec'
                : option.isCustomCapacity
                    ? (effectiveBrand == unspecifiedBrandLabel
                        ? '志工代選品牌，長輩指定容量：$spec'
                        : '長輩指定容量：$spec')
                    : referenceNote;

    final productName = (brandOverride?.trim().isNotEmpty == true)
        ? '${category.label}（${brandOverride!.trim()}）$spec'
        : option.isUnspecified ||
                (option.isCustomCapacity && effectiveBrand == unspecifiedBrandLabel)
            ? '${category.label}（$volunteerPickBrandDisplayLabel）$spec'
            : option.isCustomCapacity
                ? '${category.label}（$effectiveBrand）$spec'
                : option.isOther
                    ? '${category.label}（$effectiveBrand）$spec'
                    : option.displayName;

    return SupplyLineSnapshot(
      productId: 'tpl:${category.key}:${option.id.split(':').last}',
      productName: productName,
      quantity: quantity,
      unitPrice: option.isCustomCapacity ? null : option.refPrice,
      brand: brandOverride?.trim().isNotEmpty == true
          ? brandOverride!.trim()
          : effectiveBrand,
      spec: spec,
      unitLabel: unit,
      category: category.label,
      supplyCategoryKey: category.key,
      templateOptionId: option.isCustomCapacity ? null : option.id,
      pxSearchKeyword: option.pxSearchKeyword,
      sourceUrl: option.sourceUrl,
      imageUrl: option.imageUrl ?? category.categoryImageUrl,
      referenceNote: note,
    );
  }

  /// 依品類 key 或品名關鍵字取得離線示意 emoji。
  static String emojiForCategoryKey(String? key) {
    if (key == null || key.isEmpty) return '🛒';
    return ShopCategoryImages.emojiForSupplyKey(key);
  }

  static String emojiForOptionId(String? optionId) {
    if (optionId == null || optionId.isEmpty) return '🛒';
    final key = optionId.split(':').first;
    return emojiForCategoryKey(key);
  }

  static String emojiForDisplayName(String name) {
    final cat = findCategoryByKeyword(name);
    if (cat != null) return emojiForCategoryKey(cat.key);
    return '🛒';
  }

  static SupplyBrandOption? findOptionByTemplateId(String? templateOptionId) {
    if (templateOptionId == null || templateOptionId.isEmpty) return null;
    for (final cat in categories) {
      for (final o in cat.options) {
        if (o.id == templateOptionId) return o;
      }
    }
    return null;
  }

  static String emojiForTemplateOption(String? templateOptionId) {
    final opt = findOptionByTemplateId(templateOptionId);
    if (opt != null) return emojiForOptionId(opt.id);
    return '🛒';
  }

  static SupplyBrandOption? findBrandOption(SupplyCategory cat, String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final brands = distinctBrands(cat);
    if (RegExp(r'^\d+$').hasMatch(t)) {
      final idx = int.parse(t) - 1;
      if (idx >= 0 && idx < brands.length) return brands[idx];
    }
    for (final o in brands) {
      if (o.brand == t ||
          o.displayName.contains(t) ||
          t.contains(o.brand) ||
          (o.isUnspecified &&
              (t.contains('無指定') || t.contains('都可以') || t == '都可以'))) {
        return o;
      }
    }
    return null;
  }

  static SupplyBrandOption? findCapacityOption(
    SupplyCategory cat,
    String brand,
    String input,
  ) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final choices = capacityChoicesForBrand(cat, brand);
    if (RegExp(r'^\d+$').hasMatch(t)) {
      final idx = int.parse(t) - 1;
      if (idx >= 0 && idx < choices.length) return choices[idx];
    }
    for (final o in choices) {
      if (!o.isCustomCapacity &&
          (o.spec == t || t.contains(o.spec) || o.spec.contains(t))) {
        return o;
      }
    }
    if (t.isNotEmpty) {
      return customCapacityPicker(cat, brand);
    }
    return null;
  }

  /// 品牌步驟用：每個品牌只出現一次（保留模板順序）。
  static List<SupplyBrandOption> distinctBrands(SupplyCategory category) {
    final seen = <String>{};
    final out = <SupplyBrandOption>[];
    for (final o in category.options) {
      if (seen.add(o.brand)) out.add(o);
    }
    return out;
  }

  /// 無指定品牌時的常見容量選項（志工代選品牌）。
  static List<SupplyBrandOption> capacityPresetsForCategory(SupplyCategory category) {
    final icon = category.options.first.imageUrl ?? category.categoryImageUrl;
    final unit = category.defaultUnitLabel;
    final presets = switch (category.key) {
      'tissue' => [
        (spec: '60抽×6包', price: 119.0),
        (spec: '100抽×10包', price: 189.0),
      ],
      'egg' => [
        (spec: '6入/盒', price: 55.0),
        (spec: '10入/盒', price: 89.0),
      ],
      'milk' => [
        (spec: '185ml', price: 28.0),
        (spec: '200ml', price: 30.0),
        (spec: '500ml', price: 65.0),
        (spec: '936ml', price: 89.0),
        (spec: '1公升', price: 95.0),
      ],
      'rice' => [
        (spec: '1.5kg', price: 99.0),
        (spec: '3kg', price: 189.0),
        (spec: '5kg', price: 289.0),
      ],
      'detergent' => [
        (spec: '1.2kg', price: 129.0),
        (spec: '1.6kg', price: 139.0),
        (spec: '2.4kg', price: 199.0),
        (spec: '3.5kg', price: 219.0),
      ],
      'diaper' => [
        (spec: 'M號 10片', price: 279.0),
        (spec: 'L號 10片', price: 289.0),
      ],
      _ => <({String spec, double? price})>[],
    };
    return [
      for (var i = 0; i < presets.length; i++)
        SupplyBrandOption(
          id: '${category.key}:any:$i',
          brand: unspecifiedBrandLabel,
          displayName: '${category.label}（$unspecifiedBrandLabel）',
          spec: presets[i].spec,
          unitLabel: unit,
          refPrice: presets[i].price,
          isUnspecified: true,
          imageUrl: icon,
        ),
    ];
  }

  /// 容量步驟用：同一品牌下所有規格，末尾附「自己填容量」。
  static List<SupplyBrandOption> optionsForBrand(
    SupplyCategory category,
    String brand,
  ) {
    if (brand == unspecifiedBrandLabel) {
      return capacityPresetsForCategory(category);
    }
    final hasKnownBrand = category.options.any(
      (o) => o.brand == brand && !o.isOther && !o.isUnspecified,
    );
    if (brand == otherBrandLabel || !hasKnownBrand) {
      return capacityPresetsForCategory(category);
    }
    return category.options
        .where((o) => o.brand == brand && !o.isOther && !o.isUnspecified)
        .toList();
  }

  static List<SupplyBrandOption> capacityChoicesForBrand(
    SupplyCategory category,
    String brand,
  ) {
    return [
      ...optionsForBrand(category, brand),
      customCapacityPicker(category, brand),
    ];
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
