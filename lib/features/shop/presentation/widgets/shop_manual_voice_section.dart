import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_tts_provider.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/assistant/presentation/widgets/assistant_voice_live_panel.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shared/offline_queue/offline_queue.dart';
import 'package:smart_bp/features/shop/data/px_mart_links.dart';
import 'package:smart_bp/shared/debug/realtime_latency_tracker.dart';
import 'package:smart_bp/features/shop/data/shop_manual_voice_parser.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';
import 'package:url_launcher/url_launcher.dart';

/// 自助商品：語音＋字幕＋多品項拆分，人性化單欄填寫。
class ShopManualVoiceSection extends ConsumerStatefulWidget {
  const ShopManualVoiceSection({
    super.key,
    required this.onItemAdded,
    this.accentColor = const Color(0xFF5D4037),
  });

  final void Function(ShopProduct product, int quantity) onItemAdded;
  final Color accentColor;

  @override
  ConsumerState<ShopManualVoiceSection> createState() =>
      _ShopManualVoiceSectionState();
}

class _ShopManualVoiceSectionState extends ConsumerState<ShopManualVoiceSection> {
  final _text = TextEditingController();

  /// 待確認的解析結果（多品項），null = 尚未解析。
  List<ParsedManualVoiceItem>? _pendingItems;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// 解析輸入（優先用文字欄，再用語音即時文字）。
  List<ParsedManualVoiceItem> _parseAll(String? override) {
    final src = override?.trim().isNotEmpty == true
        ? override!.trim()
        : _text.text.trim();
    if (src.isEmpty) {
      final live = ref.read(assistantVoiceProvider).liveText.trim();
      if (live.isEmpty) return [];
      return ShopManualVoiceParser.parseMany(live);
    }
    return ShopManualVoiceParser.parseMany(src);
  }

  ShopProduct _productFrom(ParsedManualVoiceItem p) {
    return ShopProduct(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      name: p.displayName,
      category: '語音隨選',
      pxSearchKeywordOverride: p.pxSearchKeyword,
      promoText: '志工可依關鍵字至全聯門市採買',
      notes: 'voice_manual',
      fetchedAt: DateTime.now().toIso8601String(),
      confidence: 'voice',
    );
  }

  Future<void> _syncDemandDraft(List<ParsedManualVoiceItem> items) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    try {
      await ref.read(demandRecordsRepositoryProvider).addLines(
            userId: uid,
            lines: items
                .map(
                  (p) => (
                    productName: p.displayName,
                    quantity: p.quantity,
                    productId: null,
                    unitPrice: null,
                  ),
                )
                .toList(),
          );
    } catch (e) {
      // 網路或 DB 失敗 → 寫入離線佇列，恢復後 flush 僅同步草稿
      if (kDebugMode) debugPrint('[ShopVoice] Supabase failed, enqueuing: $e');
      for (final p in items) {
        await OfflineQueue.instance.enqueue(
          userId: uid,
          productName: p.displayName,
          quantity: p.quantity,
        );
      }
      // 顯示離線提示給使用者
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFE65100),
            duration: Duration(seconds: 5),
            content: Text(
              '目前無法連線，已離線暫存。連線恢復後會寫入草稿，請再到柑仔店按「送出給志工」',
              style: TextStyle(fontSize: 17),
            ),
          ),
        );
      }
    }
  }

  /// 使用者按下「確認加入」。
  Future<void> _confirmItems({required bool openPx}) async {
    final items = _pendingItems;
    if (items == null || items.isEmpty) return;

    // 記錄送出時間（Realtime 延遲量測起點）
    ref.read(realtimeLatencyProvider.notifier).markSent();

    await _syncDemandDraft(items);

    for (final p in items) {
      widget.onItemAdded(_productFrom(p), p.quantity);
    }

    if (openPx && items.isNotEmpty) {
      final first = items.first;
      await launchUrl(
        buildPxMartSearchResultUri(_productFrom(first)),
        mode: LaunchMode.externalApplication,
      );
    }

    _text.clear();
    await ref.read(assistantVoiceProvider.notifier).cancelListening();
    if (!mounted) return;

    final nameList = items.map((p) => p.displayName).join('、');
    final ttsMsg = openPx
        ? '已加入$nameList，並開啟全聯搜尋給您對照'
        : '已加入$nameList，志工端會看到這些需求';
    unawaited(ref.read(assistantTtsProvider.notifier).speak(ttsMsg));

    setState(() => _pendingItems = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openPx
              ? '已加入「$nameList」，並開啟全聯搜尋給您對照'
              : '已加入「$nameList」，志工端會看到這些需求',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// 語音或文字輸入完成後進入確認預覽。
  void _preview(String? override) {
    final items = _parseAll(override);
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請說或輸入想買的東西，例如「全聯的鮮奶兩罐」'),
        ),
      );
      return;
    }
    setState(() => _pendingItems = items);
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(assistantVoiceProvider);
    final listening = voice.isListening;
    final pending = _pendingItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 離線暫存 pending badge ─────────────────────────
        ValueListenableBuilder<int>(
          valueListenable: OfflineQueue.instance.pendingNotifier,
          builder: (context, count, _) {
            if (count <= 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE65100), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Color(0xFFE65100), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '有 $count 筆需求尚未同步\n連線恢復後會寫入草稿，請按「送出給志工」',
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.4,
                        color: Color(0xFFBF360C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        Text(
          '跟志工說想買什麼就好，不用分品牌、價格。\n'
          '例如按住麥克風說：「全聯的鮮奶兩罐，衛生紙一包」',
          style: TextStyle(fontSize: 17, height: 1.45, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),

        // ── 語音即時字幕面板 ──────────────────────────────
        if (listening)
          AssistantVoiceLivePanel(
            onConfirm: () {
              final said = ref.read(assistantVoiceProvider).liveText;
              ref.read(assistantVoiceProvider.notifier).cancelListening();
              _preview(said);
            },
            onCancel: () =>
                ref.read(assistantVoiceProvider.notifier).cancelListening(),
          ),

        // ── 文字輸入 + 按住說話 ───────────────────────────
        if (!listening && pending == null) ...[
          TextField(
            controller: _text,
            style: const TextStyle(fontSize: 20),
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '也可直接打字：鮮奶兩罐、衛生紙一包',
              hintStyle: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.mic_none, size: 28),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Listener(
            onPointerDown: (_) async {
              // 收音前停止 TTS 避免回音
              await ref.read(assistantTtsProvider.notifier).stop();
              await ref.read(assistantVoiceProvider.notifier).ensureInitialized();
              if (!ref.read(assistantVoiceProvider).isListening) {
                await ref.read(assistantVoiceProvider.notifier).toggleListening();
              }
            },
            onPointerUp: (_) async {
              if (!ref.read(assistantVoiceProvider).isListening) return;
              final said = await ref
                  .read(assistantVoiceProvider.notifier)
                  .finishListening();
              if (!mounted) return;
              _preview(said);
            },
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.mic, size: 30),
              label: const Text(
                '按住說話（可說多品項）',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                disabledBackgroundColor: widget.accentColor,
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 58),
              ),
            ),
          ),
          if (_text.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _preview(null),
              icon: const Icon(Icons.search, size: 24),
              label: const Text('預覽品項', style: TextStyle(fontSize: 17)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],

        // ── 多品項確認面板 ────────────────────────────────
        if (pending != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '確認以下品項？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                ...pending.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 22, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p.displayName}（全聯找：${p.pxSearchKeyword}）',
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _confirmItems(openPx: false),
                  icon: const Icon(Icons.check_circle_outline, size: 26),
                  label: const Text('確認加入', style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmItems(openPx: true),
                  icon: const Icon(Icons.travel_explore, size: 24),
                  label: const Text('加入＋全聯找', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _pendingItems = null),
            icon: const Icon(Icons.undo, size: 20),
            label: const Text('重新輸入', style: TextStyle(fontSize: 16)),
          ),
        ],
      ],
    );
  }
}
