/// Demo：從 Supabase `orders` / `order_items` 讀回的一筆需求單（含明細）。
final class ShopOrderListRow {
  const ShopOrderListRow({
    required this.id,
    required this.userId,
    required this.status,
    this.note,
    required this.createdAt,
    required this.items,
    this.elderDisplayName,
    this.elderPhone,
    this.totalAmount,
  });

  final String id;
  final String userId;
  final String status;
  final String? note;
  final DateTime createdAt;
  final List<ShopOrderItemRow> items;

  /// 若志工可讀 `profiles` 則為姓名，否則為 null（UI 改顯示編號）。
  final String? elderDisplayName;

  /// 若志工可讀 `profiles.phone`。
  final String? elderPhone;

  /// 訂單參考總額（與 DB `total_amount` 一致，可為 null）。
  final int? totalAmount;

  int get totalQuantity =>
      items.fold<int>(0, (sum, e) => sum + e.quantity);
}

final class ShopOrderItemRow {
  const ShopOrderItemRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double? unitPrice;
}
