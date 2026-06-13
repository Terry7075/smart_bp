import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// 提供給下層 [VideoCard] 取用的播放範圍。
///
/// 由 [LearningVideoHost] 在頁面層級建立,讓「目前播放中的影片」與「共用的
/// 單一播放器 widget」可以被任一張卡片讀到:只有 `activeKey` 相符的卡片才會
/// 把 [sharedPlayer] 嵌入自己的版面。
class LearningVideoScope extends InheritedWidget {
  const LearningVideoScope({
    super.key,
    required this.activeKey,
    required this.sharedPlayer,
    required this.play,
    required this.stop,
    required super.child,
  });

  /// 目前正在播放的影片 key(以影片網址當 key);null 表示沒有任何影片在播。
  final String? activeKey;

  /// 全頁共用的單一 [YoutubePlayer] widget;只有在播放中才非 null。
  final Widget? sharedPlayer;

  /// 開始播放某支影片。
  final void Function(String videoId, String key) play;

  /// 停止播放並還原直屏。
  final VoidCallback stop;

  static LearningVideoScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<LearningVideoScope>();
    assert(
      scope != null,
      'LearningVideoScope not found. 請用 LearningVideoHost 包住頁面。',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(LearningVideoScope oldWidget) =>
      activeKey != oldWidget.activeKey ||
      !identical(sharedPlayer, oldWidget.sharedPlayer);
}

/// 頁面層級的 YouTube 播放宿主。
///
/// 為什麼要拉到頁面層級?
/// - `youtube_player_flutter` 的全螢幕是在 [YoutubePlayerBuilder] 自己的 widget
///   樹位置,用 `player` 取代 `child`。若 builder 被放在 ListView 的卡片內,橫屏時
///   只能填满卡片格子,無法鋪满整個螢幕。
/// - 因此把唯一的 [YoutubePlayerBuilder] 提升到 Scaffold 外層,全頁共用一個
///   controller / player;橫屏時整頁被 player 取代 → 真正全螢幕鋪满。
/// - 單一 controller 也天然保證「同時只播一支影片」。
class LearningVideoHost extends StatefulWidget {
  const LearningVideoHost({super.key, required this.child});

  /// 頁面內容(通常是 `DefaultTabController` + `Scaffold`)。
  final Widget child;

  @override
  State<LearningVideoHost> createState() => _LearningVideoHostState();
}

class _LearningVideoHostState extends State<LearningVideoHost> {
  YoutubePlayerController? _controller;
  String? _activeKey;

  static void _restorePortraitUi() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _enterFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _play(String videoId, String key) {
    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    );
    setState(() => _activeKey = key);
  }

  void _stop() {
    _controller?.dispose();
    _controller = null;
    _restorePortraitUi();
    if (mounted) setState(() => _activeKey = null);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restorePortraitUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    // 尚未播放任何影片:不建立 YoutubePlayerBuilder,只提供 scope。
    if (controller == null) {
      return LearningVideoScope(
        activeKey: null,
        sharedPlayer: null,
        play: _play,
        stop: _stop,
        child: widget.child,
      );
    }

    // 播放中:YoutubePlayerBuilder 包住整頁,橫屏時由它接管整個螢幕。
    return YoutubePlayerBuilder(
      onEnterFullScreen: _enterFullScreen,
      onExitFullScreen: _restorePortraitUi,
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFFC62828),
        bottomActions: const [
          CurrentPosition(),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) => LearningVideoScope(
        activeKey: _activeKey,
        sharedPlayer: player,
        play: _play,
        stop: _stop,
        child: widget.child,
      ),
    );
  }
}

/// 監聽最近的 [DefaultTabController]，分頁切換時停止學習影片播放。
///
/// 為什麼需要？`TabBarView` 會讓離屏分頁的子樹保持掛載，播放中的影片卡片
/// 不會被卸載 → 切到另一個分頁後音訊仍繼續播。這裡在分頁 index 改變時主動
/// 呼叫 [LearningVideoScope.stop]（同時還原直屏）。
///
/// 放置位置必須是 [DefaultTabController] 的子孫、且在 [LearningVideoHost] 之內，
/// 才同時讀得到 TabController 與影片播放範圍。
///
/// 注意：請把 [DefaultTabController] 放在 [LearningVideoHost] **之上**，否則
/// 播放／停止時 host 會切換 build 根節點型別，連帶把 TabController 的 state
/// 一起重建，導致分頁跳回第一頁。
class StopVideoOnTabChange extends StatefulWidget {
  const StopVideoOnTabChange({super.key, required this.child});

  final Widget child;

  @override
  State<StopVideoOnTabChange> createState() => _StopVideoOnTabChangeState();
}

class _StopVideoOnTabChangeState extends State<StopVideoOnTabChange> {
  TabController? _controller;
  int? _lastIndex;

  void _onTabChanged() {
    final c = _controller;
    if (c == null) return;
    // 同時涵蓋「點分頁」與「滑動切換」：只要目標 index 變了就停播。
    if (c.index != _lastIndex) {
      _lastIndex = c.index;
      LearningVideoScope.of(context).stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = DefaultTabController.of(context);
    if (!identical(c, _controller)) {
      _controller?.removeListener(_onTabChanged);
      _controller = c;
      _lastIndex = c.index;
      c.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
