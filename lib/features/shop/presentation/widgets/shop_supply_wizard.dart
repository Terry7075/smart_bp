import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/features/shop/data/supply_dialogue_service.dart';
import 'package:smart_bp/features/shop/domain/pending_supply_dialogue.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';

/// 柑仔店四層代購精靈：類別 → 品牌 → 數量 → 提示送出。
class ShopSupplyWizard extends ConsumerStatefulWidget {
  const ShopSupplyWizard({super.key});

  @override
  ConsumerState<ShopSupplyWizard> createState() => _ShopSupplyWizardState();
}

class _ShopSupplyWizardState extends ConsumerState<ShopSupplyWizard> {
  SupplyCategory? _category;
  SupplyBrandOption? _option;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '常用物資代購',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '選類別 → 品牌 → 數量，加入後請按上方「送出給志工」',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_category == null) _buildCategories() else ...[
              if (_option == null) _buildBrands() else _buildQtyStep(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in ElderSupplyTemplates.categories)
          ActionChip(
            label: Text(c.label, style: const TextStyle(fontSize: 18)),
            onPressed: () => setState(() {
              _category = c;
              _option = null;
              _qty = 1;
            }),
          ),
      ],
    );
  }

  Widget _buildBrands() {
    final cat = _category!;
    final pending = PendingSupplyDialogue(
      categoryKey: cat.key,
      categoryLabel: cat.label,
      quantity: _qty,
      unitLabel: cat.defaultUnitLabel,
      categoryImageUrl: cat.categoryImageUrl,
    );
    final ask = SupplyDialogueService().brandAskReplyFor(pending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇${cat.label}品牌',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        BrandChoiceList(
          choices: ask.brandChoices,
            onTapChoice: (c) {
            final opt = cat.options.firstWhere((o) => o.id == c.optionId);
            if (opt.isOther) {
              setState(() => _option = opt);
              return;
            }
            setState(() => _option = opt);
          },
        ),
        TextButton(
          onPressed: () => setState(() => _category = null),
          child: const Text('← 重選類別'),
        ),
      ],
    );
  }

  Widget _buildQtyStep() {
    final opt = _option!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${opt.brand} · ${opt.displayName}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove_circle_outline, size: 32),
            ),
            Text('$_qty ${opt.unitLabel}', style: const TextStyle(fontSize: 22)),
            IconButton(
              onPressed: () => setState(() => _qty++),
              icon: const Icon(Icons.add_circle_outline, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _addToDraft,
          child: const Text('加入採買清單', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => setState(() => _option = null),
          child: const Text('← 重選品牌'),
        ),
      ],
    );
  }

  Future<void> _addToDraft() async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    final snap = ElderSupplyTemplates.buildSnapshot(
      category: _category!,
      option: _option!,
      quantity: _qty,
    );
    try {
      await ref.read(demandRecordsRepositoryProvider).addSnapshotLines(
            userId: uid,
            lines: [snap],
          );
      ref.invalidate(elderDemandDraftProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入：${snap.productName} × $_qty')),
      );
      setState(() {
        _category = null;
        _option = null;
        _qty = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失敗：$e')),
      );
    }
  }
}
