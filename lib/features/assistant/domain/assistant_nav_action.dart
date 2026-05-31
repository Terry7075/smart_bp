/// 小幫手回覆附帶的一鍵導航按鈕。
class AssistantNavAction {
  const AssistantNavAction({
    required this.label,
    this.route,
    this.homeTab,
    this.sendMessageOnTap,
    this.queryParameters,
  }) : assert(
          route != null || homeTab != null || sendMessageOnTap != null,
          '需提供 route、homeTab 或 sendMessageOnTap',
        );

  final String label;

  /// GoRouter 路徑（例如 `/shop`、`/profile`）。
  final String? route;

  /// 首頁底部導覽索引（0=首頁 … 5=活動）；與 [route] `/home` 併用。
  final int? homeTab;

  /// 點擊後在小幫手內再送一則使用者訊息（例如「好，幫我買衛生紙」）。
  final String? sendMessageOnTap;

  /// 導向時附帶查詢參數（例如價格頁 `q=衛生紙`）。
  final Map<String, String>? queryParameters;

  Map<String, dynamic> toJson() => {
        'label': label,
        if (route != null) 'route': route,
        if (homeTab != null) 'home_tab': homeTab,
        if (sendMessageOnTap != null) 'send_message': sendMessageOnTap,
        if (queryParameters != null && queryParameters!.isNotEmpty)
          'query': queryParameters,
      };

  factory AssistantNavAction.fromJson(Map<String, dynamic> json) {
    final rawQuery = json['query'];
    Map<String, String>? query;
    if (rawQuery is Map) {
      query = rawQuery.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    }
    return AssistantNavAction(
      label: json['label']?.toString() ?? '前往',
      route: json['route']?.toString(),
      homeTab: (json['home_tab'] as num?)?.toInt(),
      sendMessageOnTap: json['send_message']?.toString(),
      queryParameters: query,
    );
  }
}
