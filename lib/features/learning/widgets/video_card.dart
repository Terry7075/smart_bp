import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../learning_content_models.dart';

/// 目前正在播放的影片 key（用影片網址當 key）。
///
/// 為什麼要拉到全域 provider？
/// - 每張 [VideoCard] 各自管自己的 controller，沒有協調者時，長輩快速點兩張
///   影片會同時播放、兩個聲音疊在一起。
/// - 改成全域只記「一個正在播的 key」：任一張卡開始播放就把這個值設成自己，
///   其他卡 watch 到值變了、且不是自己，就自動停止並釋放 controller。
final currentlyPlayingVideoProvider =
    NotifierProvider<CurrentlyPlayingVideo, String?>(CurrentlyPlayingVideo.new);

class CurrentlyPlayingVideo extends Notifier<String?> {
  @override
  String? build() => null;

  /// 設為正在播放的影片 key。
  void play(String key) => state = key;

  /// 只有當前播放的就是 [key] 時才清空，避免誤清掉別張卡。
  void stopIf(String key) {
    if (state == key) state = null;
  }
}

/// 高齡友善 YouTube 卡片：縮圖預覽，點擊後於卡片內播放。
class VideoCard extends ConsumerStatefulWidget {
  const VideoCard({
    super.key,
    required this.title,
    required this.url,
    this.description,
  });

  final String title;
  final String url;
  final String? description;

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard> {
  YoutubePlayerController? _controller;
  bool _playing = false;
  String? _error;

  /// 這張卡的唯一識別：用網址即可（同頁不會有兩筆完全一樣的網址）。
  String get _videoKey => widget.url.trim();

  static void _restorePortraitUi() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  void dispose() {
    // 若這張卡正在播放就被銷毀（離開頁面、清單重建），先把全域「正在播放」key
    // 清掉，否則它會殘留指向一張已不存在的卡，影響後續單一播放協調。
    if (_playing) {
      ref.read(currentlyPlayingVideoProvider.notifier).stopIf(_videoKey);
    }
    _controller?.dispose();
    _restorePortraitUi();
    super.dispose();
  }

  void _startPlay() {
    final videoId = youtubeVideoIdFromUrl(widget.url);
    if (videoId == null) {
      setState(() => _error = '這支影片的網址看不懂，可以改用 YouTube App 開啟。');
      return;
    }

    // 通知全域：現在由「我」播放，其他卡會自動停。
    ref.read(currentlyPlayingVideoProvider.notifier).play(_videoKey);

    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
    setState(() {
      _playing = true;
      _error = null;
    });
  }

  void _stopPlay({bool clearGlobal = true}) {
    _controller?.dispose();
    _controller = null;
    _restorePortraitUi();
    if (clearGlobal) {
      ref.read(currentlyPlayingVideoProvider.notifier).stopIf(_videoKey);
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null) {
      if (mounted) {
        setState(() => _error = '網址格式不正確，無法開啟。');
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '找不到可以開啟影片的 App',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 監聽全域播放 key：若別張卡開始播放（值 != 自己），把自己停掉。
    ref.listen<String?>(currentlyPlayingVideoProvider, (prev, next) {
      if (_playing && next != _videoKey) {
        _stopPlay(clearGlobal: false);
      }
    });

    final videoId = youtubeVideoIdFromUrl(widget.url);
    final thumbUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
        : null;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _playing && _controller != null
                ? YoutubePlayerBuilder(
                    onEnterFullScreen: () {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    },
                    onExitFullScreen: _restorePortraitUi,
                    player: YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: const Color(0xFFC62828),
                      bottomActions: const [
                        CurrentPosition(),
                        ProgressBar(isExpanded: true),
                        RemainingDuration(),
                        FullScreenButton(),
                      ],
                    ),
                    builder: (context, player) => player,
                  )
                : _PreviewLayer(
                    thumbUrl: thumbUrl,
                    error: _error,
                    onPlay: _startPlay,
                    onOpenExternal: _openInYoutube,
                  ),
          ),
          if (_playing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _stopPlay(),
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
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Colors.black87,
                  ),
                ),
                if (widget.description != null &&
                    widget.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.description!,
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
                  child: Icon(Icons.ondemand_video,
                      size: 72, color: Colors.white54),
                ),
              )
            else
              const ColoredBox(
                color: Color(0xFF424242),
                child:
                    Icon(Icons.ondemand_video, size: 72, color: Colors.white54),
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
                          label: const Text('再試一次',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenExternal,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 22),
                          label: const Text('用 YouTube 開啟',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
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
                child:
                    const Icon(Icons.play_arrow, size: 48, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
