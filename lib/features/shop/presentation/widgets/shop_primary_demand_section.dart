import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_supply_dialogue_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_voice_demand_bar.dart';

/// 柑仔店主流程：語音 → 品牌確認 → 草稿 → 送出志工。
class ShopPrimaryDemandSection extends ConsumerStatefulWidget {
  const ShopPrimaryDemandSection({
    super.key,
    this.highlightSubmit = false,
  });

  /// 小幫手 `?focus=submit` 導向時強調送出鈕。
  final bool highlightSubmit;

  @override
  ConsumerState<ShopPrimaryDemandSection> createState() =>
      _ShopPrimaryDemandSectionState();
}

class _ShopPrimaryDemandSectionState
    extends ConsumerState<ShopPrimaryDemandSection> {
  static const Color _green = Color(0xFF2E7D32);

  final _text = TextEditingController();
  bool _submitting = false;
  final _submitKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.highlightSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '草稿已同步，請按下方綠色「送出給志工」按鈕',
              style: TextStyle(fontSize: 17),
            ),
            duration: Duration(seconds: 4),
          ),
        );
        final ctx = _submitKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submitText() async {
    final raw = _text.text.trim();
    if (raw.isEmpty) return;
    final err = await ref
        .read(shopSupplyDialogueProvider.notifier)
        .handleUtterance(raw);
    _text.clear();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _submitToVolunteer() async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    if (ref.read(shopSupplyDialogueProvider).awaitingBrand) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先完成品牌選擇，再送出給志工')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId =
          await ref.read(demandRecordsRepositoryProvider).submitDraftToOrders(
                userId: uid,
                ordersRepo: ref.read(shopOrdersRepositoryProvider),
              );
      ref.invalidate(elderDemandDraftProvider);
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(shopElderOrdersProvider);
      ref.read(shopSupplyDialogueProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已送出給志工（單號：${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}…）\n志工將收到通知並協助代購',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogue = ref.watch(shopSupplyDialogueProvider);
    final draft = ref.watch(elderDemandDraftProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '① 說出需求　② 選品牌　③ 送出給志工',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '從這裡開始即可。常用物資如衛生紙、鮮奶會先請您選品牌，不會直接送出。',
                  style: TextStyle(fontSize: 16, height: 1.35, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const ShopVoiceDemandBar(autoApplyOnRelease: true),
        if (dialogue.promptText != null && dialogue.awaitingBrand) ...[
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '請選擇品牌',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dialogue.promptText!,
                    style: const TextStyle(fontSize: 17, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  BrandChoiceList(
                    choices: dialogue.brandChoices,
                    enabled: !dialogue.busy,
                    onTapChoice: (c) async {
                      final err = await ref
                          .read(shopSupplyDialogueProvider.notifier)
                          .selectBrand(c);
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        if (dialogue.lastMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            dialogue.lastMessage!,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _text,
          style: const TextStyle(fontSize: 20),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: '或打字：我要衛生紙兩包',
            hintStyle: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _submitText(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: dialogue.busy ? null : _submitText,
          icon: const Icon(Icons.edit_note, size: 24),
          label: const Text('解析文字並加入草稿', style: TextStyle(fontSize: 17)),
        ),
        const SizedBox(height: 16),
        const Text(
          '目前採買清單（草稿）',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        draft.when(
          loading: () => const LinearProgressIndicator(color: _green),
          error: (e, _) => Text('讀取草稿失敗：$e', style: const TextStyle(fontSize: 16)),
          data: (record) {
            final items = record?.activeItems ?? const [];
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '尚無品項。請用語音或上方文字記錄需求。',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final it in items)
                    ListTile(
                      title: Text(
                        it.brand != null && it.brand!.isNotEmpty
                            ? '${it.productName}（${it.brand}）'
                            : it.productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: it.referenceNote != null
                          ? Text(it.referenceNote!, style: const TextStyle(fontSize: 15))
                          : null,
                      trailing: Text(
                        '× ${it.quantity}${it.unitLabel ?? ""}',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: _submitKey,
          onPressed: _submitting ? null : _submitToVolunteer,
          icon: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, size: 26),
          label: Text(
            _submitting ? '送出中…' : '送出給志工',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            minimumSize: const Size(double.infinity, 56),
            side: widget.highlightSubmit
                ? const BorderSide(color: Color(0xFFFFB300), width: 3)
                : BorderSide.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '送出後志工會收到通知；您也可在「我的需求單」查看進度（家屬需另建帳號並綁定長輩）。',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.3),
        ),
      ],
    );
  }
}
