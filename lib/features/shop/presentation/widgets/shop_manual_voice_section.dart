import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/presentation/assistant_voice_provider.dart';
import 'package:smart_bp/features/assistant/presentation/widgets/assistant_voice_live_panel.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/px_mart_links.dart';
import 'package:smart_bp/features/shop/data/shop_manual_voice_parser.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';
import 'package:url_launcher/url_launcher.dart';

/// 自助商品：語音＋字幕＋一句話（全聯搜尋關鍵字），人性化單欄填寫。
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  ParsedManualVoiceItem? _parseCurrent() {
    final fromText = ShopManualVoiceParser.parse(_text.text);
    if (fromText.isValid) return fromText;
    final live = ref.read(assistantVoiceProvider).liveText.trim();
    if (live.isEmpty) return null;
    return ShopManualVoiceParser.parse(live);
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

  Future<void> _syncDemandDraft(ParsedManualVoiceItem p) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    try {
      await ref.read(demandRecordsRepositoryProvider).addLines(
            userId: uid,
            lines: [
              (
                productName: p.displayName,
                quantity: p.quantity,
                productId: null,
                unitPrice: null,
              ),
            ],
          );
    } catch (_) {
      // 表未建時仍可在本站清單送出
    }
  }

  Future<void> _commit({required bool openPx, String? rawOverride}) async {
    if (rawOverride != null && rawOverride.trim().isNotEmpty) {
      _text.text = rawOverride.trim();
    }
    final p = _parseCurrent();
    if (p == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請說或輸入想買的東西，例如「全聯的鮮奶兩罐」'),
        ),
      );
      return;
    }

    await _syncDemandDraft(p);
    final product = _productFrom(p);
    widget.onItemAdded(product, p.quantity);

    if (openPx) {
      await launchUrl(
        buildPxMartSearchResultUri(product),
        mode: LaunchMode.externalApplication,
      );
    }

    _text.clear();
    await ref.read(assistantVoiceProvider.notifier).cancelListening();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openPx
              ? '已加入「${p.displayName}」，並開啟全聯搜尋給您對照'
              : '已加入「${p.displayName}」，志工端會看到這筆需求',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(assistantVoiceProvider);
    final listening = voice.isListening;
    final parsed = _parseCurrent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '跟志工說想買什麼就好，不用分品牌、價格。\n'
          '例如按住麥克風說：「全聯的鮮奶兩罐」',
          style: TextStyle(fontSize: 17, height: 1.45, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        if (listening)
          AssistantVoiceLivePanel(
            onConfirm: () => _commit(openPx: false),
            onCancel: () =>
                ref.read(assistantVoiceProvider.notifier).cancelListening(),
          ),
        if (!listening) ...[
          TextField(
            controller: _text,
            style: const TextStyle(fontSize: 20),
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '也可以直接打字：全聯衛生紙一包',
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
              await _commit(openPx: false, rawOverride: said);
            },
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.mic, size: 30),
              label: const Text(
                '按住說話（會顯示字幕）',
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
        ],
        if (!listening) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _commit(openPx: false),
                  icon: const Icon(Icons.check_circle_outline, size: 26),
                  label: const Text('加入需求', style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _commit(openPx: true),
                  icon: const Icon(Icons.travel_explore, size: 24),
                  label: const Text('全聯找', style: TextStyle(fontSize: 17)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
            ],
          ),
        ],
        if (parsed != null && !listening) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '志工會看到：${parsed.displayName}\n全聯搜尋：${parsed.pxSearchKeyword}',
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}
