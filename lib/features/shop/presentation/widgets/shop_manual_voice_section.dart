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
import 'package:smart_bp/features/shop/data/shop_demand_completeness.dart';
import 'package:smart_bp/features/shop/data/shop_manual_voice_parser.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/shared/debug/realtime_latency_tracker.dart';
import 'package:url_launcher/url_launcher.dart';

/// 找全聯商品：關鍵字導向全聯搜尋，或解析後加入採買清單（可語音）。
class ShopManualVoiceSection extends ConsumerStatefulWidget {
  const ShopManualVoiceSection({super.key});

  @override
  ConsumerState<ShopManualVoiceSection> createState() =>
      _ShopManualVoiceSectionState();
}

class _ShopManualVoiceSectionState extends ConsumerState<ShopManualVoiceSection> {
  final _text = TextEditingController();

  List<ParsedManualVoiceItem>? _pendingItems;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _inputText {
    final typed = _text.text.trim();
    if (typed.isNotEmpty) return typed;
    return ref.read(assistantVoiceProvider).liveText.trim();
  }

  List<ParsedManualVoiceItem> _parseAll([String? override]) {
    final src = (override ?? _inputText).trim();
    if (src.isEmpty) return [];
    return ShopManualVoiceParser.parseMany(src);
  }

  Future<void> _openPxSearch([String? keyword]) async {
    final kw = (keyword ?? _inputText).trim();
    if (kw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入想搜尋的商品關鍵字')),
      );
      return;
    }
    final uri = buildPxMartUriFromName(kw);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯搜尋，請稍後再試')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已開啟全聯搜尋：$kw')),
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
      ref.invalidate(elderDemandDraftProvider);
    } catch (e) {
      if (kDebugMode) debugPrint('[ShopPxSearch] Supabase failed, enqueuing: $e');
      for (final p in items) {
        await OfflineQueue.instance.enqueue(
          userId: uid,
          productName: p.displayName,
          quantity: p.quantity,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFE65100),
            duration: Duration(seconds: 5),
            content: Text(
              '目前無法連線，已離線暫存。連線恢復後會寫入採買清單。',
              style: TextStyle(fontSize: 17),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmItems({bool openPx = false}) async {
    final items = _pendingItems;
    if (items == null || items.isEmpty) return;

    final vague = items.where((p) =>
        ShopDemandCompleteness.needsBrandCapacityPrompt(p.pxSearchKeyword));
    if (vague.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text(
            '請寫清楚品牌與容量，志工才好採買。不確定請用上方常用物資',
            style: TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }

    ref.read(realtimeLatencyProvider.notifier).markSent();
    await _syncDemandDraft(items);

    if (openPx) {
      await _openPxSearch(items.first.pxSearchKeyword);
    }

    _text.clear();
    await ref.read(assistantVoiceProvider.notifier).cancelListening();
    if (!mounted) return;

    final nameList = items.map((p) => p.displayName).join('、');
    setState(() => _pendingItems = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入採買清單：$nameList'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _previewForDraft([String? override]) {
    final items = _parseAll(override);
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入想買的商品關鍵字')),
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
              child: Text(
                '有 $count 筆需求暫存本機，連線恢復後會寫入採買清單',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFBF360C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        if (listening)
          AssistantVoiceLivePanel(
            onConfirm: () {
              final said = ref.read(assistantVoiceProvider).liveText;
              ref.read(assistantVoiceProvider.notifier).cancelListening();
              if (said.trim().isNotEmpty) _text.text = said.trim();
              _previewForDraft(said);
            },
            onCancel: () =>
                ref.read(assistantVoiceProvider.notifier).cancelListening(),
          ),
        if (!listening && pending == null) ...[
          TextField(
            controller: _text,
            style: const TextStyle(fontSize: 20),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _openPxSearch(v),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '輸入關鍵字',
              hintStyle: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, size: 28),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _inputText.isEmpty ? null : () => _openPxSearch(),
                  icon: const Icon(Icons.storefront_outlined, size: 24),
                  label: const Text(
                    '全聯搜尋',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _inputText.isEmpty ? null : () => _previewForDraft(),
                  icon: const Icon(Icons.add_shopping_cart_outlined, size: 24),
                  label: const Text(
                    '加入清單',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Listener(
            onPointerDown: (_) async {
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
              if (said != null && said.trim().isNotEmpty) {
                _text.text = said.trim();
                _previewForDraft(said);
              }
            },
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.mic, size: 26),
              label: const Text(
                '按住說話',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: const Color(0xFF5D4037),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
        if (pending != null) ...[
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
                  '確認加入採買清單？',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                if (pending.any((p) =>
                    ShopDemandCompleteness.needsBrandCapacityPrompt(
                        p.pxSearchKeyword))) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '請寫清楚品牌與容量，志工才好採買',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBF360C),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                for (final p in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '· ${p.displayName}',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _confirmItems(),
            icon: const Icon(Icons.check_circle_outline, size: 26),
            label: const Text('確認加入', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmItems(openPx: true),
                  icon: const Icon(Icons.storefront_outlined, size: 22),
                  label: const Text('加入並全聯搜尋', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _pendingItems = null),
                child: const Text('取消', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
