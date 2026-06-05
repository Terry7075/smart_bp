import 'package:smart_bp/features/shop/data/product_catalog.dart';
import 'package:smart_bp/features/shop/data/shop_quantity_parser.dart';
import 'package:smart_bp/features/shop/domain/canonical_product.dart';
import 'package:smart_bp/features/shop/domain/supply_line_snapshot.dart';

/// 商品標準化引擎（PNE）：語句 → [CanonicalProduct]。
class ProductNormalizationEngine {
  ProductNormalizationEngine({ProductCatalog? catalog})
      : _catalog = catalog ?? ProductCatalog.instance;

  final ProductCatalog _catalog;

  CanonicalProduct normalize(String rawUtterance) {
    final parsed = ShopQuantityParser.parseCategoryRequest(rawUtterance);
    if (parsed == null) {
      return const CanonicalProduct(
        category: '未識別',
        categoryKey: 'unknown',
        quantity: 1,
        confidence: 0.2,
        matchLayer: 'L5_fallback',
      );
    }

    var remainder = parsed.categoryKeyword.trim();
    final qty = parsed.quantity;
    final unit = parsed.unitLabel;

    // L1/L2：品牌最長匹配
    CatalogBrand? matchedBrand;
    String matchLayer = 'L3_category_keyword';
    var confidence = 0.75;

    final sortedBrands = <CatalogBrand>[];
    for (final c in _catalog.categories) {
      sortedBrands.addAll(c.brands.where((b) => !b.isOther));
    }
    sortedBrands.sort((a, b) => b.brandName.length.compareTo(a.brandName.length));

    for (final b in sortedBrands) {
      if (remainder.contains(b.brandName)) {
        matchedBrand = b;
        remainder = remainder.replaceAll(b.brandName, '').trim();
        matchLayer = 'L1_brand_exact';
        confidence = 0.95;
        break;
      }
    }

    if (matchedBrand == null) {
      for (final entry in _catalog.synonymToBrandId.entries) {
        if (remainder.contains(entry.key)) {
          matchedBrand = _catalog.brandById(entry.value);
          if (matchedBrand != null) {
            remainder = remainder.replaceAll(entry.key, '').trim();
            matchLayer = 'L2_brand_synonym';
            confidence = 0.88;
            break;
          }
        }
      }
    }

    CatalogCategory? cat;
    if (matchedBrand != null) {
      cat = _catalog.categoryByKey(matchedBrand.categoryKey);
    }
    cat ??= _catalog.resolveCategory(remainder.isEmpty ? parsed.categoryKeyword : remainder);
    cat ??= _catalog.resolveCategory(parsed.categoryKeyword);

    if (cat == null) {
      return CanonicalProduct(
        category: parsed.categoryKeyword,
        categoryKey: 'unknown',
        brand: matchedBrand?.brandName,
        brandId: matchedBrand?.id,
        quantity: qty,
        unitLabel: unit,
        confidence: 0.4,
        matchLayer: 'L5_fallback',
        needsBrandClarification: matchedBrand == null,
      );
    }

    final needsBrand = matchedBrand == null;

    if (matchedBrand == null) {
      confidence = 0.7;
      matchLayer = 'L4_category_only';
    }

    return CanonicalProduct(
      category: cat.label,
      categoryKey: cat.key,
      brand: matchedBrand?.brandName,
      brandId: matchedBrand?.id,
      quantity: qty,
      unitLabel: unit ?? cat.defaultUnitLabel,
      spec: matchedBrand?.spec,
      confidence: confidence,
      matchLayer: matchLayer,
      templateOptionId: matchedBrand?.templateOptionId,
      pxSearchKeyword: matchedBrand?.pxSearchKeyword,
      imageUrl: matchedBrand?.imageUrl ?? cat.imageUrl,
      needsBrandClarification: needsBrand,
    );
  }

  SupplyLineSnapshot? toSnapshot(CanonicalProduct canonical) {
    if (canonical.categoryKey == 'unknown') return null;
    final cat = _catalog.categoryByKey(canonical.categoryKey);
    if (cat == null) return null;

    CatalogBrand? brand;
    if (canonical.brandId != null) {
      brand = _catalog.brandById(canonical.brandId!);
    } else if (canonical.brand != null) {
      brand = _catalog.brandByName['${cat.key}:${canonical.brand}'];
    }

    if (brand != null && !brand.isOther) {
      return SupplyLineSnapshot(
        productId: 'tpl:${cat.key}:${brand.id.split(':').last}',
        productName: brand.displayName,
        quantity: canonical.quantity,
        unitPrice: brand.refPrice,
        brand: brand.brandName,
        spec: brand.spec,
        unitLabel: canonical.unitLabel ?? brand.unitLabel,
        category: cat.label,
        supplyCategoryKey: cat.key,
        templateOptionId: brand.templateOptionId,
        pxSearchKeyword: brand.pxSearchKeyword,
        imageUrl: brand.imageUrl ?? cat.imageUrl,
        categoryId: canonical.categoryId,
        brandId: canonical.brandId,
        normalizeConfidence: canonical.confidence,
      );
    }

    return SupplyLineSnapshot(
      productId: 'cat:${cat.key}',
      productName: cat.label,
      quantity: canonical.quantity,
      unitLabel: canonical.unitLabel ?? cat.defaultUnitLabel,
      category: cat.label,
      supplyCategoryKey: cat.key,
      imageUrl: cat.imageUrl,
      categoryId: canonical.categoryId,
      normalizeConfidence: canonical.confidence,
    );
  }
}
