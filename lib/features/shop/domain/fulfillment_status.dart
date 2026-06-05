/// 品項履行狀態（志工採買 → 發放）。
enum ItemFulfillmentStatus {
  pending('pending', '待採買'),
  accepted('accepted', '已接單'),
  purchased('purchased', '已購買'),
  delivered('delivered', '已發放'),
  cancelled('cancelled', '已取消'),
  substituted('substituted', '已替代');

  const ItemFulfillmentStatus(this.value, this.label);
  final String value;
  final String label;

  static ItemFulfillmentStatus? fromValue(String? v) {
    if (v == null) return null;
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}
