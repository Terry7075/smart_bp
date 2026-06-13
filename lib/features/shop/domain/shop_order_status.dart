/// 訂單與配送事件的中文標籤（畢專：配送時間軸）。
abstract final class ShopOrderStatus {
  static const created = 'created';
  static const accepted = 'accepted';
  /// 統一里程碑：採買＋配送（取代 purchasing / delivering）。
  static const procuring = 'procuring';
  static const purchasing = 'purchasing';
  static const delivering = 'delivering';
  static const delivered = 'delivered';
  static const issue = 'issue';

  static String orderStatusLabel(String status) {
    return switch (status) {
      'pending' => '待接單',
      'processing' => '已接單',
      'completed' => '已送達活動中心',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  /// 長輩列表用：processing 且已標記採買中時顯示「採買中」。
  static String elderOrderStatusLabel(String status, {bool hasProcuring = false}) {
    if (status == 'processing' && hasProcuring) return '採買中';
    return orderStatusLabel(status);
  }

  static String eventTypeLabel(String type) {
    return switch (type) {
      created => '需求已送出',
      accepted => '志工已接單',
      procuring => '採買中',
      purchasing => '採買中',
      delivering => '採買中',
      delivered => '已送達活動中心',
      issue => '配送狀況',
      _ => type,
    };
  }

  static bool isProcuringMilestone(String type) =>
      type == procuring || type == purchasing || type == delivering;
}
