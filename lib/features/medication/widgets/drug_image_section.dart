import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../drug_dictionary_service.dart';

/// 外部藥典圖床常擋預設請求；帶瀏覽器 UA 提高載入成功率。
const Map<String, String> kDrugImageRequestHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

/// 主 URL + 備援 URL，並為 `http://` 自動補 `https://` 變體。
List<String> expandDrugImageAttemptUrls(
  String primary, {
  List<String> fallbacks = const [],
}) {
  final out = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final normalized = normalizeExternalImageUrl(raw);
    if (normalized.isEmpty || !seen.add(normalized)) return;
    out.add(normalized);
    if (normalized.startsWith('http://')) {
      final https = 'https://${normalized.substring(7)}';
      if (seen.add(https)) out.add(https);
    }
  }

  add(primary);
  for (final f in fallbacks) {
    add(f);
  }
  return out;
}
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
          DrugImageMatched(
            :final imageUrl,
            :final fallbackUrls,
            :final exactBrand,
            :final referenceNote,
          ) =>
            _ImageView(
              imageUrl: imageUrl,
              fallbackUrls: fallbackUrls,
              heroTag: heroTag,
              exactBrand: exactBrand,
              referenceNote: referenceNote,
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
  const _ImageView({
    required this.imageUrl,
    required this.heroTag,
    this.fallbackUrls = const [],
    this.exactBrand = true,
    this.referenceNote,
  });

  final String imageUrl;
  final List<String> fallbackUrls;
  final String heroTag;
  final bool exactBrand;
  final String? referenceNote;

  List<String> get _attemptUrls =>
      expandDrugImageAttemptUrls(imageUrl, fallbacks: fallbackUrls);

  @override
  Widget build(BuildContext context) {
    final note = referenceNote;
    final showNote = !exactBrand && note != null && note.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            exactBrand ? '藥典照片（點擊可放大）' : '參考照片（點擊可放大）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (showNote)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE65100), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: () => _openFullscreen(context),
          child: Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _ResilientDrugImage(
                urls: _attemptUrls,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
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
            attemptUrls: _attemptUrls,
            heroTag: heroTag,
          ),
        ),
      ),
    );
  }
}

/// 依序嘗試多個 URL；失敗時改以 http 下載位元組（部分政府／醫院站較吃這招）。
class _ResilientDrugImage extends StatefulWidget {
  const _ResilientDrugImage({
    required this.urls,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingColor,
    this.errorWidget,
  });

  final List<String> urls;
  final double? height;
  final BoxFit fit;
  final Color? loadingColor;
  final Widget? errorWidget;

  @override
  State<_ResilientDrugImage> createState() => _ResilientDrugImageState();
}

class _ResilientDrugImageState extends State<_ResilientDrugImage> {
  int _urlIndex = 0;
  Uint8List? _bytes;
  bool _failed = false;
  bool _httpFetchStarted = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget ?? _defaultError(context);
    }
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: double.infinity,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.errorWidget ?? _defaultError(context),
      );
    }
    if (widget.urls.isEmpty) {
      return widget.errorWidget ?? _defaultError(context);
    }
    if (_urlIndex >= widget.urls.length) {
      _startHttpFetchOnce();
      return _loading();
    }

    final url = widget.urls[_urlIndex];
    return Image.network(
      url,
      key: ValueKey('drug-img-$url'),
      width: double.infinity,
      height: widget.height,
      fit: widget.fit,
      headers: kDrugImageRequestHeaders,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _loading(progress: progress);
      },
      errorBuilder: (_, err, __) {
        // ignore: avoid_print
        print('[DrugImage] network failed "$url": $err');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _urlIndex >= widget.urls.length) return;
          setState(() => _urlIndex++);
        });
        return _loading();
      },
    );
  }

  void _startHttpFetchOnce() {
    if (_httpFetchStarted) return;
    _httpFetchStarted = true;
    _fetchBytesFallback();
  }

  Future<void> _fetchBytesFallback() async {
    for (final url in widget.urls) {
      try {
        final resp = await http
            .get(Uri.parse(url), headers: kDrugImageRequestHeaders)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode < 200 || resp.statusCode >= 400) continue;
        if (resp.bodyBytes.isEmpty) continue;
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();
        if (ct.isNotEmpty && !ct.startsWith('image/')) continue;
        if (!mounted) return;
        setState(() => _bytes = resp.bodyBytes);
        return;
      } catch (e) {
        // ignore: avoid_print
        print('[DrugImage] http bytes failed "$url": $e');
      }
    }
    if (!mounted) return;
    setState(() => _failed = true);
  }

  Widget _loading({ImageChunkEvent? progress}) {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: CircularProgressIndicator(
          color: widget.loadingColor,
          value: progress?.expectedTotalBytes != null
              ? progress!.cumulativeBytesLoaded /
                  progress.expectedTotalBytes!
              : null,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Container(
      height: widget.height ?? 200,
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
}

// ---------------------------------------------------------------------------
// 全螢幕檢視（可縮放）
// ---------------------------------------------------------------------------

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.attemptUrls,
    required this.heroTag,
  });

  final List<String> attemptUrls;
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
            child: _ResilientDrugImage(
              urls: attemptUrls,
              fit: BoxFit.contain,
              loadingColor: Colors.white,
              errorWidget: const Center(
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
