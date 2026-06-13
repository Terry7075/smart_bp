import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learning_content_models.dart';
import 'learning_content_provider.dart';
import 'widgets/learning_content_list.dart';
import 'widgets/learning_video_host.dart';

/// 社區學習：防詐騙宣導、健康小教室（動態內容）。
class CommunityLearningPage extends ConsumerWidget {
  const CommunityLearningPage({super.key});

  static const Color _primaryBlue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAll = ref.watch(learningContentProvider);

    // DefaultTabController 必須在 LearningVideoHost 之上：host 在播放／停止時
    // 會切換 build 根節點，若 TabController 在 host 之下會被一起重建 → 分頁跳回
    // 第一頁、且切分頁要按兩次。
    return DefaultTabController(
      length: 2,
      child: LearningVideoHost(
        child: StopVideoOnTabChange(
          child: Scaffold(
            backgroundColor: const Color(0xFFFFF8E1),
            appBar: AppBar(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              toolbarHeight: 72,
              title: const Text(
                '社區學習',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: '🛡️ 防詐騙宣導'),
                  Tab(text: '🏥 健康小教室'),
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
                    items: filterByCategory(all, LearningCategory.antiFraud),
                    emptyMessage: '目前沒有防詐宣導內容。',
                  ),
                  LearningContentList(
                    items: filterByCategory(all, LearningCategory.health),
                    emptyMessage: '目前沒有健康小教室內容。',
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
                  backgroundColor: CommunityLearningPage._primaryBlue,
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
