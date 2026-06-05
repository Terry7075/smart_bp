import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';

/// 記憶體商品目錄（由 [ElderSupplyTemplates] 建構，可與 Supabase 同步）。
final class CatalogBrand {
  const CatalogBrand({
    required this.id,
    required this.categoryKey,
    required this.brandName,
    required this.displayName,
    required this.spec,
    required this.unitLabel,
    this.refPrice,
    this.templateOptionId,
    this.pxSearchKeyword,
    this.imageUrl,
    this.isOther = false,
  });

  final String id;
  final String categoryKey;
  final String brandName;
  final String displayName;
  final String spec;
  final String unitLabel;
  final double? refPrice;
  final String? templateOptionId;
  final String? pxSearchKeyword;
  final String? imageUrl;
  final bool isOther;
}

final class CatalogCategory {
  const CatalogCategory({
    required this.key,
    required this.label,
    required this.keywords,
    required this.defaultUnitLabel,
    required this.brands,
    this.imageUrl,
  });

  final String key;
  final String label;
  final List<String> keywords;
  final String defaultUnitLabel;
  final List<CatalogBrand> brands;
  final String? imageUrl;
}

final class ProductCatalog {
  ProductCatalog._({
    required this.categories,
    required this.brandByName,
    required this.synonymToCategoryKey,
    required this.synonymToBrandId,
  });

  final List<CatalogCategory> categories;
  final Map<String, CatalogBrand> brandByName;
  final Map<String, String> synonymToCategoryKey;
  final Map<String, String> synonymToBrandId;

  static final ProductCatalog instance = ProductCatalog._build();

  static ProductCatalog _build() {
    final categories = <CatalogCategory>[];
    final brandByName = <String, CatalogBrand>{};
    final synonymToCategoryKey = <String, String>{};
    final synonymToBrandId = <String, String>{};

    for (final c in ElderSupplyTemplates.categories) {
      final brands = <CatalogBrand>[];
      for (final o in c.options) {
        final b = CatalogBrand(
          id: o.id,
          categoryKey: c.key,
          brandName: o.brand,
          displayName: o.displayName,
          spec: o.spec,
          unitLabel: o.unitLabel,
          refPrice: o.refPrice,
          templateOptionId: o.id,
          pxSearchKeyword: o.pxSearchKeyword,
          imageUrl: o.imageUrl,
          isOther: o.isOther,
        );
        brands.add(b);
        brandByName['${c.key}:${o.brand}'] = b;
        synonymToBrandId[o.brand.toLowerCase()] = o.id;
        if (o.brand == '五月花') {
          synonymToBrandId['五月花'] = o.id;
        }
      }
      categories.add(
        CatalogCategory(
          key: c.key,
          label: c.label,
          keywords: [...c.keywords, c.label],
          defaultUnitLabel: c.defaultUnitLabel,
          brands: brands,
          imageUrl: c.categoryImageUrl,
        ),
      );
      for (final k in c.keywords) {
        synonymToCategoryKey[k.toLowerCase()] = c.key;
      }
      synonymToCategoryKey[c.label.toLowerCase()] = c.key;
    }

    synonymToBrandId['春風'] = 'tissue:chunfeng';

    const extraCategorySynonyms = <String, String>{
      '面紙': 'tissue',
      '紙巾': 'tissue',
      '抽取式': 'tissue',
      '抽取式衛生紙': 'tissue',
    };
    synonymToCategoryKey.addAll(extraCategorySynonyms);

    return ProductCatalog._(
      categories: categories,
      brandByName: brandByName,
      synonymToCategoryKey: synonymToCategoryKey,
      synonymToBrandId: synonymToBrandId,
    );
  }

  CatalogCategory? categoryByKey(String key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }

  CatalogBrand? brandById(String id) {
    for (final c in categories) {
      for (final b in c.brands) {
        if (b.id == id) return b;
      }
    }
    return null;
  }

  CatalogCategory? resolveCategory(String text) {
    final n = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (n.isEmpty) return null;
    CatalogCategory? best;
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
}
