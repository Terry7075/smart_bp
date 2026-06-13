import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learning_content_models.dart';
import 'learning_content_provider.dart';
import 'widgets/learning_content_list.dart';
import 'widgets/learning_video_host.dart';

/// 客語資訊：認字、歌謠、故事館（動態內容）。
class HakkaCulturePage extends ConsumerWidget {
  const HakkaCulturePage({super.key});

  static const Color _hakkaTeal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAll = ref.watch(learningContentProvider);

    // DefaultTabController 必須在 LearningVideoHost 之上（見 community_learning_page
    // 的說明）：否則播放／停止影片時 TabController 會被重建，分頁跳回第一頁。
    return DefaultTabController(
      length: 3,
      child: LearningVideoHost(
        child: StopVideoOnTabChange(
          child: Scaffold(
            backgroundColor: const Color(0xFFFFF8E1),
            appBar: AppBar(
              backgroundColor: _hakkaTeal,
              foregroundColor: Colors.white,
              toolbarHeight: 72,
              title: const Text(
                '🗣️ 客語資訊',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              bottom: const TabBar(
                isScrollable: false,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: '🔤 認字'),
                  Tab(text: '🎵 歌謠'),
                  Tab(text: '📖 故事館'),
                ],
              ),
            ),
            body: asyncAll.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBody(
                message: '讀取內容失敗：\n${learningContentFriendlyError(e)}',
                onRetry: () =>
                    ref.read(learningContentProvider.notifier).refresh(),
              ),
              data: (all) => TabBarView(
                children: [
                  LearningContentList(
                    items: filterByCategory(all, LearningCategory.hakkaVocab),
                    emptyMessage: '目前沒有客語認字內容。',
                  ),
                  LearningContentList(
                    items: filterByCategory(all, LearningCategory.hakkaSong),
                    emptyMessage: '目前沒有客家歌謠內容。',
                  ),
                  LearningContentList(
                    items: filterByCategory(all, LearningCategory.hakkaStory),
                    emptyMessage: '目前沒有客庄故事內容。',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: HakkaCulturePage._hakkaTeal,
                ),
                child: const Text(
                  '再試一次',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
