/// 訂單與配送事件的中文標籤（畢專：配送時間軸）。
abstract final class ShopOrderStatus {
  static const created = 'created';
  static const accepted = 'accepted';
  static const purchasing = 'purchasing';
  static const delivering = 'delivering';
  static const delivered = 'delivered';
  static const issue = 'issue';

  static String orderStatusLabel(String status) {
    return switch (status) {
      'pending' => '已送出（待處理）',
      'processing' => '志工處理中',
      'completed' => '已送達',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  static String eventTypeLabel(String type) {
    return switch (type) {
      created => '需求已送出',
      accepted => '志工已接單',
      purchasing => '採買中',
      delivering => '配送中',
      delivered => '已送達長輩',
      issue => '配送狀況',
      _ => type,
    };
  }
}
