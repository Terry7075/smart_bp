import 'package:flutter/material.dart';

import '../learning_content_models.dart';
import 'article_card.dart';
import 'video_card.dart';

/// 依內容型態渲染 VideoCard / ArticleCard 列表。
class LearningContentList extends StatelessWidget {
  const LearningContentList({
    super.key,
    required this.items,
    this.emptyMessage = '目前還沒有內容，請稍後再來看看。',
  });

  final List<LearningContent> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isVideo) {
          return VideoCard(
            title: item.title,
            url: item.url,
            description: item.description,
          );
        }
        return ArticleCard(
          title: item.title,
          url: item.url,
          description: item.description,
        );
      },
    );
  }
}
