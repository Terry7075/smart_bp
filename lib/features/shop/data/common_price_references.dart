import 'package:smart_bp/features/shop/data/price_references_repository.dart';

/// 長輩常問、但柑仔店種子目錄可能未收錄的參考價（全聯門市為準，僅供估算）。
abstract final class CommonPriceReferences {
  static const List<PriceReference> items = [
    PriceReference(
      id: 'local-toilet-paper',
      productName: '衛生紙',
      unitPrice: 89,
      unitLabel: '串／包',
      category: '日用品',
      sourceNote: '常見參考',
    ),
    PriceReference(
      id: 'local-rice',
      productName: '白米',
      unitPrice: 199,
      unitLabel: '3kg',
      category: '米糧',
      sourceNote: '常見參考',
    ),
    PriceReference(
      id: 'local-eggs',
      productName: '雞蛋',
      unitPrice: 89,
      unitLabel: '10入',
      category: '生鮮',
      sourceNote: '常見參考',
    ),
    PriceReference(
      id: 'local-soy-sauce',
      productName: '醬油',
      unitPrice: 65,
      unitLabel: '瓶',
      category: '調味',
      sourceNote: '常見參考',
    ),
    PriceReference(
      id: 'local-milk',
      productName: '鮮奶',
      unitPrice: 89,
      unitLabel: '瓶',
      category: '乳品',
      sourceNote: '常見參考',
    ),
    PriceReference(
      id: 'local-bread',
      productName: '吐司',
      unitPrice: 39,
      unitLabel: '包',
      category: '麵包',
      sourceNote: '常見參考',
    ),
  ];
}
