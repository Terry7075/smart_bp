/// 小幫手回覆附帶的一鍵導航按鈕。
class AssistantNavAction {
  const AssistantNavAction({
    required this.label,
    this.route,
    this.homeTab,
  }) : assert(
          route != null || homeTab != null,
          '需提供 route 或 homeTab',
        );

  final String label;

  /// GoRouter 路徑（例如 `/shop`、`/profile`）。
  final String? route;

  /// 首頁底部導覽索引（0=首頁 … 5=活動）；與 [route] `/home` 併用。
  final int? homeTab;

  Map<String, dynamic> toJson() => {
        'label': label,
        if (route != null) 'route': route,
        if (homeTab != null) 'home_tab': homeTab,
      };

  factory AssistantNavAction.fromJson(Map<String, dynamic> json) {
    return AssistantNavAction(
      label: json['label']?.toString() ?? '前往',
      route: json['route']?.toString(),
      homeTab: (json['home_tab'] as num?)?.toInt(),
    );
  }
}
