import 'package:flutter/material.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';

/// 志工／長輩清單列：品牌 · 品名 · 規格 · 數量。
class ShoppingLineTile extends StatelessWidget {
  ShoppingLineTile.fromDemandItem({
    super.key,
    required DemandRecordItem item,
  })  : productName = item.productName,
        quantity = item.quantity,
        unitPrice = item.unitPrice,
        _brand = item.brand,
        _spec = item.spec,
        _unitLabel = item.unitLabel,
        _referenceNote = item.referenceNote;

  ShoppingLineTile.fromOrderItem({
    super.key,
    required ShopOrderItemRow item,
  })  : productName = item.productName,
        quantity = item.quantity,
        unitPrice = item.unitPrice,
        _brand = item.brand,
        _spec = item.spec,
        _unitLabel = item.unitLabel,
        _referenceNote = item.referenceNote;

  final String productName;
  final int quantity;
  final double? unitPrice;
  final String? _brand;
  final String? _spec;
  final String? _unitLabel;
  final String? _referenceNote;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final brand = _brand?.trim();
    if (brand != null && brand.isNotEmpty) parts.add(brand);
    parts.add(productName);
    final spec = _spec?.trim();
    if (spec != null && spec.isNotEmpty) parts.add(spec);
    final title = parts.join(' · ');
    final unit = _unitLabel?.trim();
    final qtyLine = unit != null && unit.isNotEmpty
        ? '× $quantity $unit'
        : '× $quantity';
    final price = unitPrice != null && unitPrice! > 0
        ? '參考約 ${unitPrice!.toInt()} 元'
        : null;
    final note = _referenceNote?.trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(qtyLine, style: const TextStyle(fontSize: 17)),
          if (price != null)
            Text(price, style: const TextStyle(fontSize: 16, color: Color(0xFF2E7D32))),
          if (note != null && note.isNotEmpty)
            Text(
              '備註：$note',
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
