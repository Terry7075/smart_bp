/// 本機或自建「圖片跳板」基底網址（不含結尾 `/`）。
///
/// 搭配 `scripts/image_proxy_server.mjs`，編譯／執行時加上：
/// `flutter run --dart-define=IMAGE_PROXY_BASE=http://127.0.0.1:8788`
///
/// Android 模擬器連電腦上的跳板請改用 `http://10.0.2.2:8788`。
String resolveShopImageUrl(String rawUrl) {
  const base = String.fromEnvironment('IMAGE_PROXY_BASE');
  if (base.isEmpty) return rawUrl;
  final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$trimmed/image-proxy?url=${Uri.encodeComponent(rawUrl)}';
}
