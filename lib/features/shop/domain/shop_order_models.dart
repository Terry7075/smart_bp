import 'package:smart_bp/features/shop/domain/shop_order_status.dart';

/// 配送時間軸一筆事件（`order_delivery_events`）。
final class OrderDeliveryEvent {
  const OrderDeliveryEvent({
    required this.id,
    required this.orderId,
    required this.eventType,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String eventType;
  final String? note;
  final DateTime createdAt;

  factory OrderDeliveryEvent.fromMap(Map<String, dynamic> map) {
    return OrderDeliveryEvent(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? '',
      note: map['note']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

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
    this.assignedVolunteerId,
    this.deliveredAt,
    this.deliveryIssue,
    this.deliveryEvents = const [],
    this.locationPointId,
    this.locationPointName,
    this.isUrgent = false,
  });

  final String id;
  final String userId;
  final String status;
  final String? note;
  final DateTime createdAt;
  final List<ShopOrderItemRow> items;
  final String? assignedVolunteerId;
  final DateTime? deliveredAt;
  final String? deliveryIssue;
  final List<OrderDeliveryEvent> deliveryEvents;

  /// 長輩標記為緊急需求，志工端優先排序並顯示紅色徽章。
  final bool isUrgent;

  /// 若志工可讀 `profiles` 則為姓名，否則為 null（UI 改顯示編號）。
  final String? elderDisplayName;

  /// 若志工可讀 `profiles.phone`。
  final String? elderPhone;

  /// 訂單參考總額（與 DB `total_amount` 一致，可為 null）。
  final int? totalAmount;

  final String? locationPointId;
  final String? locationPointName;

  int get totalQuantity =>
      items.fold<int>(0, (sum, e) => sum + e.quantity);

  /// 是否已標記代購中（含舊版採買中／配送中事件）。
  bool get hasProcuringMilestone => deliveryEvents.any(
        (e) => ShopOrderStatus.isProcuringMilestone(e.eventType),
      );

  /// 時間軸顯示用：若尚無事件，至少顯示「已送出」。
  List<OrderDeliveryEvent> get timelineEvents {
    if (deliveryEvents.isNotEmpty) return deliveryEvents;
    return [
      OrderDeliveryEvent(
        id: '',
        orderId: id,
        eventType: 'created',
        createdAt: createdAt,
      ),
    ];
  }
}

final class ShopOrderItemRow {
  const ShopOrderItemRow({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unitPrice,
    this.category,
    this.unitLabel,
    this.brand,
    this.spec,
    this.supplyCategoryKey,
    this.templateOptionId,
    this.referenceNote,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double? unitPrice;

  /// 下單當下分類快照（清潔用品/米糧…），來自 order_items.category。
  final String? category;

  /// 下單當下計價單位快照（包/瓶/罐…），來自 order_items.unit_label。
  final String? unitLabel;
  final String? brand;
  final String? spec;
  final String? supplyCategoryKey;
  final String? templateOptionId;
  final String? referenceNote;
}

/// 長輩歷史訂單加總後的常購提示（非 ML 推薦）。
final class FrequentShopItem {
  const FrequentShopItem({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
  });

  final String productId;
  final String productName;
  final int totalQuantity;
}
