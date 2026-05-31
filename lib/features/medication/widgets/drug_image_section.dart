import 'package:flutter/material.dart';

import '../drug_dictionary_service.dart';

/// 藥典照片區塊：根據 [future] 結果顯示藥品圖片、「未建檔」提示或錯誤訊息。
///
/// - [DrugImageMatched]  → 顯示圖片縮圖，可點擊全螢幕放大（Hero 動畫）
/// - [DrugImageNotFound] → 顯示「藥典尚無此藥品圖片」
/// - [DrugImageLookupFailed] → 顯示「暫時無法查詢」＋重試按鈕
///
/// 使用時機：
///   - 打卡頁（[MedicationCheckinPage]）— 協助長輩「看圖認藥」
///   - OCR 確認頁（[HealthScanPage] SuccessView）— 確認辨識結果
class DrugImageSection extends StatelessWidget {
  const DrugImageSection({
    super.key,
    required this.future,
    required this.heroTag,
    this.onRetry,
  });

  /// 藥典圖片查詢 Future（由父層建立並管理，避免 rebuild 重查）。
  final Future<DrugImageLookup> future;

  /// Hero 動畫 tag，需在同一路由堆疊下唯一。
  final String heroTag;

  /// 失敗時的重試回呼；傳 null 則不顯示重試按鈕。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DrugImageLookup>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _FailedView(
            reason: '查詢時發生錯誤',
            onRetry: onRetry,
          );
        }
        return switch (snapshot.data) {
          DrugImageMatched(:final imageUrl) => _ImageView(
              imageUrl: imageUrl,
              heroTag: heroTag,
            ),
          DrugImageNotFound() => const _NotFoundView(),
          DrugImageLookupFailed(:final reason) => _FailedView(
              reason: reason,
              onRetry: onRetry,
            ),
          null => const _NotFoundView(),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 載入中
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('查詢藥典中…', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 有圖：縮圖 + 點擊全螢幕
// ---------------------------------------------------------------------------

class _ImageView extends StatelessWidget {
  const _ImageView({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '藥典照片（點擊可放大）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openFullscreen(context),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2.5,
                      ),
                    ),
                  );
                },
                errorBuilder: (ctx, err, st) => _errorPlaceholder(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorPlaceholder(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('圖片載入失敗', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: animation,
          child: _FullscreenImagePage(
            imageUrl: imageUrl,
            heroTag: heroTag,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 全螢幕檢視（可縮放）
// ---------------------------------------------------------------------------

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('藥典照片'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 8,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (ctx, err, st) => const Center(
                child: Text(
                  '圖片載入失敗',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 未找到
// ---------------------------------------------------------------------------

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_search_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '藥典尚無此藥品照片\n（比對功能仍為試驗性質）',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 查詢失敗
// ---------------------------------------------------------------------------

class _FailedView extends StatelessWidget {
  const _FailedView({required this.reason, this.onRetry});

  final String reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '暫時無法查詢藥典圖片',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重試'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}
