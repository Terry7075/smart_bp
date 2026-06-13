import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../learning_content_models.dart';
import 'learning_video_host.dart';

/// 高齡友善 YouTube 卡片：縮圖預覽,點擊後於卡片內播放。
///
/// 播放器本身由頁面層級的 [LearningVideoHost] 統一管理(單一 controller),
/// 本卡片只負責:把播放鈕接到 [LearningVideoScope.play]、在自己是「目前播放中
/// 那張卡」時把共用 player 嵌進版面。如此一來全螢幕時才能由頁面層級接管整個畫面。
class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.title,
    required this.url,
    this.description,
  });

  final String title;
  final String url;
  final String? description;

  /// 這張卡的唯一識別：用網址即可(同頁不會有兩筆完全一樣的網址)。
  String get _videoKey => url.trim();

  Future<void> _openInYoutube(BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      _showSnack(context, '網址格式不正確,無法開啟。');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showSnack(context, '找不到可以開啟影片的 App');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = LearningVideoScope.of(context);
    final videoId = youtubeVideoIdFromUrl(url);
    final thumbUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
        : null;

    // 只有「目前播放中的那張卡」且 host 已備妥共用 player 時,才把 player 嵌入。
    final isActive =
        videoId != null &&
        scope.activeKey == _videoKey &&
        scope.sharedPlayer != null;

    return _buildCard(
      videoChild: isActive
          ? scope.sharedPlayer!
          : _PreviewLayer(
              thumbUrl: thumbUrl,
              error: videoId == null ? '這支影片的網址看不懂,可以改用 YouTube App 開啟。' : null,
              onPlay: videoId == null
                  ? () => _openInYoutube(context)
                  : () => scope.play(videoId, _videoKey),
              onOpenExternal: () => _openInYoutube(context),
            ),
      showStopButton: isActive,
      onStop: scope.stop,
    );
  }

  Widget _buildCard({
    required Widget videoChild,
    required bool showStopButton,
    required VoidCallback onStop,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: videoChild),
          if (showStopButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 26),
                  label: const Text(
                    '關閉影片',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Colors.black87,
                  ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLayer extends StatelessWidget {
  const _PreviewLayer({
    required this.thumbUrl,
    required this.onPlay,
    required this.onOpenExternal,
    this.error,
  });

  final String? thumbUrl;
  final VoidCallback onPlay;
  final VoidCallback onOpenExternal;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Material(
      color: Colors.black87,
      // 即使出錯也保留點擊（重試播放）；播不出來時下方另給「YouTube 開啟」鈕。
      child: InkWell(
        onTap: onPlay,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (thumbUrl != null)
              Image.network(
                thumbUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF424242),
                  child: Icon(
                    Icons.ondemand_video,
                    size: 72,
                    color: Colors.white54,
                  ),
                ),
              )
            else
              const ColoredBox(
                color: Color(0xFF424242),
                child: Icon(
                  Icons.ondemand_video,
                  size: 72,
                  color: Colors.white54,
                ),
              ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onPlay,
                          icon: const Icon(Icons.refresh, size: 22),
                          label: const Text(
                            '再試一次',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenExternal,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 22),
                          label: const Text(
                            '用 YouTube 開啟',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
