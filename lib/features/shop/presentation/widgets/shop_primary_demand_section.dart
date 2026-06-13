import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/features/volunteer/widgets/volunteer_shop_confirm_dialog.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/presentation/shop_supply_dialogue_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/procurement_day_banner.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';
import 'package:smart_bp/features/shared/offline_queue/offline_queue.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_elder_ui.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_supply_wizard.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_voice_demand_bar.dart';

/// 柑仔店主流程：填寫需求 → 品牌確認 → 草稿 → 送出志工。
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
  bool _submitting = false;
  bool _draftBusy = false;
  bool _offlinePromptOpen = false;
  final _submitKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    OfflineQueue.instance.lastFlushSyncedCount.addListener(_onOfflineDraftSynced);
    if (widget.highlightSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '離線需求已同步至採買清單，請按下方綠色「送出給志工」按鈕',
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
    OfflineQueue.instance.lastFlushSyncedCount
        .removeListener(_onOfflineDraftSynced);
    super.dispose();
  }

  void _onOfflineDraftSynced() {
    final synced = OfflineQueue.instance.lastFlushSyncedCount.value;
    if (synced <= 0 || !mounted || _offlinePromptOpen) return;
    OfflineQueue.instance.lastFlushSyncedCount.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showOfflineSubmitPrompt(synced);
    });
  }

  Future<void> _showOfflineSubmitPrompt(int syncedCount) async {
    if (_offlinePromptOpen) return;
    _offlinePromptOpen = true;
    ref.invalidate(elderDemandDraftProvider);
    await ref.read(elderDemandDraftProvider.future);
    if (!mounted) {
      _offlinePromptOpen = false;
      return;
    }
    final draft = ref.read(elderDemandDraftProvider).asData?.value;
    final itemCount = draft?.activeItems.length ?? syncedCount;
    if (itemCount <= 0) {
      _offlinePromptOpen = false;
      return;
    }
    final submitNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '連線已恢復',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '已將 $syncedCount 筆離線需求寫入採買清單（共 $itemCount 項）。\n'
          '要立即送出給志工嗎？',
          style: const TextStyle(fontSize: 18, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍後再送', style: TextStyle(fontSize: 17)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('立即送出', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
    _offlinePromptOpen = false;
    if (submitNow == true && mounted) {
      await _submitToVolunteer();
    }
  }

  Future<void> _submitToVolunteer() async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    if (ref.read(shopSupplyDialogueProvider).hasPendingDialogue) {
      final step = ref.read(shopSupplyDialogueProvider).pending?.step;
      final isCapacity = step == SupplyDialogueStep.awaitCapacity ||
          step == SupplyDialogueStep.awaitCustomCapacity;
      final isOtherNote = step == SupplyDialogueStep.awaitOtherNote;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOtherNote
                ? '請先說出或選擇品牌名稱'
                : isCapacity
                    ? '請先選完容量，再送出給志工'
                    : '請先完成品牌選擇，再送出給志工',
          ),
        ),
      );
      return;
    }

    ref.invalidate(elderDemandDraftProvider);
    final draft = await ref.read(elderDemandDraftProvider.future);
    final active = draft?.activeItems ?? const [];
    if (active.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先加入至少一項需求')),
      );
      return;
    }

    final summary = active
        .map(
          (i) => ElderSupplyTemplates.formatDraftLineSummary(
            productName: i.productName,
            brand: i.brand,
            spec: i.spec,
            quantity: i.quantity,
            unitLabel: i.unitLabel,
          ),
        )
        .join('\n');

    final elderNote = await VolunteerShopConfirmDialog.confirmElderSubmit(
      context,
      itemCount: active.length,
      itemsSummary: summary,
    );
    if (elderNote == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(demandRecordsRepositoryProvider).submitDraftToOrders(
            userId: uid,
            ordersRepo: ref.read(shopOrdersRepositoryProvider),
            elderNote: elderNote.isEmpty ? null : elderNote,
          );
      await ref
          .read(demandRecordsRepositoryProvider)
          .getOrCreateDraft(userId: uid);
      ref.invalidate(elderDemandDraftProvider);
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(shopElderOrdersProvider);
      ref.read(shopSupplyDialogueProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ 已送出給志工！請至「我的需求進度」查看狀態。',
            style: TextStyle(fontSize: 18),
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '查看進度',
            textColor: Colors.white,
            onPressed: () => context.push('/shop/orders'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final detail = e is AuthException
          ? e.message
          : e is PostgrestException
              ? (e.message)
              : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '送出失敗：$detail',
            style: const TextStyle(fontSize: 16),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _refreshDraft() async {
    ref.invalidate(elderDemandDraftProvider);
    await ref.read(elderDemandDraftProvider.future);
  }

  Future<void> _removeDraftItem(DemandRecordItem item) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    setState(() => _draftBusy = true);
    try {
      await ref.read(demandRecordsRepositoryProvider).removeDraftItemById(
            userId: uid,
            itemId: item.id,
          );
      await _refreshDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法移除品項：$e')),
      );
    } finally {
      if (mounted) setState(() => _draftBusy = false);
    }
  }

  Future<void> _changeDraftQuantity(DemandRecordItem item, int delta) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    final next = item.quantity + delta;
    setState(() => _draftBusy = true);
    try {
      await ref.read(demandRecordsRepositoryProvider).updateDraftItemQuantity(
            userId: uid,
            itemId: item.id,
            quantity: next,
          );
      await _refreshDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法更新數量：$e')),
      );
    } finally {
      if (mounted) setState(() => _draftBusy = false);
    }
  }

  String? _draftSubtitle(String? spec, String? referenceNote) {
    final parts = <String>[
      if ((spec ?? '').trim().isNotEmpty) spec!.trim(),
      if ((referenceNote ?? '').trim().isNotEmpty) referenceNote!.trim(),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Widget _buildSubmitReminder(int itemCount) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return Card(
      color: ShopElderUi.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFFFB300), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB300),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '請按下方「送出給志工」',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _activeStep(PendingSupplyDialogue? pending, int itemCount) {
    if (itemCount > 0) return 3;
    if (pending != null) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final dialogue = ref.watch(shopSupplyDialogueProvider);
    final draft = ref.watch(elderDemandDraftProvider);
    final itemCount = draft.asData?.value?.activeItems.length ?? 0;
    final step = _activeStep(dialogue.pending, itemCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProcurementDayBanner(),
        ShopElderUi.sectionGap(12),
        ElderStepRow(activeStep: step),
        ShopElderUi.sectionGap(12),
        ShopElderUi.sectionTitle('填寫物資需求'),
        const ShopSupplyWizard(),
        ShopElderUi.sectionGap(16),
        const ShopVoiceDemandBar(autoApplyOnRelease: true),
        if (dialogue.awaitingOtherNote && dialogue.promptText != null) ...[
          ShopElderUi.sectionGap(16),
          Card(
            color: const Color(0xFFFFF3E0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                dialogue.promptText!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.35),
              ),
            ),
          ),
        ],
        if (dialogue.promptText != null &&
            dialogue.brandChoices.isNotEmpty &&
            dialogue.pending != null) ...[
          ShopElderUi.sectionGap(16),
          Card(
            color: const Color(0xFFFFF3E0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    dialogue.awaitingCapacity ? '③ 請選容量' : '② 請選擇品牌',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dialogue.promptText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  BrandChoiceList(
                    choices: dialogue.brandChoices,
                    enabled: !dialogue.busy,
                    displayMode: dialogue.awaitingCapacity
                        ? BrandPickDisplayMode.capacityOnly
                        : BrandPickDisplayMode.brandOnly,
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
          ShopElderUi.sectionGap(10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              dialogue.lastMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade900,
              ),
            ),
          ),
        ],
        ShopElderUi.sectionGap(24),
        ShopElderUi.sectionTitle('📋 目前採買清單'),
        draft.when(
          loading: () => const LinearProgressIndicator(color: ShopElderUi.green),
          error: (e, _) => const Text(
            '讀取清單失敗，請稍後再試。',
            style: TextStyle(fontSize: 16),
          ),
          data: (record) {
            final items = record?.activeItems ?? const [];
            if (items.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '尚無品項',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, height: 1.5),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final it in items)
                  ElderDraftItemCard(
                    title: it.brand != null && it.brand!.isNotEmpty
                        ? '${it.productName}（${it.brand}）'
                        : it.productName,
                    subtitle: _draftSubtitle(it.spec, it.referenceNote),
                    quantity: it.quantity,
                    unitLabel: it.unitLabel ?? '',
                    enabled: !_draftBusy && !_submitting,
                    onDecrease: () => _changeDraftQuantity(it, -1),
                    onIncrease: () => _changeDraftQuantity(it, 1),
                    onRemove: () => _removeDraftItem(it),
                  ),
              ],
            );
          },
        ),
        ShopElderUi.sectionGap(16),
        _buildSubmitReminder(itemCount),
        if (itemCount > 0) ShopElderUi.sectionGap(12),
        OutlinedButton.icon(
          onPressed: () => context.push('/shop/orders'),
          icon: const Icon(Icons.receipt_long, size: 26),
          label: const Text(
            '查看我的需求進度',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: ShopElderUi.green,
            side: const BorderSide(color: ShopElderUi.green, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
        ShopElderUi.sectionGap(12),
        ElderPrimaryButton(
          key: _submitKey,
          label: '送出給志工',
          loading: _submitting,
          highlight: widget.highlightSubmit,
          tall: itemCount > 0,
          onPressed: _submitToVolunteer,
        ),
      ],
    );
  }
}
