import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/presentation/shop_draft_providers.dart';
import 'package:smart_bp/features/shop/presentation/widgets/brand_choice_list.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_elder_ui.dart';

/// 常用物資：① 品類 → ② 品牌 → ③ 容量（含價格）與數量。
class ShopSupplyWizard extends ConsumerStatefulWidget {
  const ShopSupplyWizard({super.key});

  @override
  ConsumerState<ShopSupplyWizard> createState() => _ShopSupplyWizardState();
}

class _ShopSupplyWizardState extends ConsumerState<ShopSupplyWizard> {
  SupplyCategory? _category;
  String? _selectedBrand;
  SupplyBrandOption? _option;
  String? _customSpec;
  final _customSpecController = TextEditingController();
  final _customSpecFocus = FocusNode();
  final _otherBrandController = TextEditingController();
  final _summaryAnchorKey = GlobalKey();
  int _qty = 1;
  final _scrollTargetKey = GlobalKey();

  @override
  void dispose() {
    _customSpecController.dispose();
    _customSpecFocus.dispose();
    _otherBrandController.dispose();
    super.dispose();
  }

  void _resetToCategories() {
    setState(() {
      _category = null;
      _selectedBrand = null;
      _option = null;
      _customSpec = null;
      _customSpecController.clear();
      _otherBrandController.clear();
      _qty = 1;
    });
  }

  void _scrollToStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _scrollTargetKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  void _selectCategory(SupplyCategory c) {
    setState(() {
      _category = c;
      _selectedBrand = null;
      _option = null;
      _qty = 1;
    });
    _scrollToStep();
  }

  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = brand;
      _option = null;
      _customSpec = null;
      _customSpecController.clear();
      _otherBrandController.clear();
      _qty = 1;
    });
    _scrollToStep();
  }

  void _selectCapacity(SupplyBrandOption opt) {
    setState(() {
      _option = opt;
      _customSpec = null;
      _customSpecController.clear();
      _otherBrandController.clear();
      _qty = 1;
    });
  }

  void _confirmCustomSpec() {
    final text = _customSpecController.text.trim();
    if (text.isEmpty) return;
    final cat = _category!;
    final brand = _selectedBrand!;
    setState(() {
      _customSpec = text;
      _option = ElderSupplyTemplates.customCapacityPicker(cat, brand);
      _qty = 1;
    });
    _scrollToSummary();
  }

  void _scrollToSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _summaryAnchorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
    });
  }

  String _summaryTitle(SupplyCategory cat) {
    final opt = _option!;
    final spec = _effectiveSpec ?? '';
    if (opt.isUnspecified || opt.brand == ElderSupplyTemplates.unspecifiedBrandLabel) {
      return '${cat.label}（${ElderSupplyTemplates.volunteerPickBrandDisplayLabel}）$spec';
    }
    if (opt.isCustomCapacity) {
      return '${cat.label}（${opt.brand}）$spec';
    }
    return opt.displayName;
  }

  String? get _effectiveSpec {
    if (_customSpec != null && _customSpec!.isNotEmpty) return _customSpec;
    return _option?.spec;
  }

  bool get _isOtherBrand =>
      _selectedBrand == ElderSupplyTemplates.otherBrandLabel;

  bool get _canAddToDraft {
    if (_option == null) return false;
    if (_isOtherBrand && _otherBrandController.text.trim().isEmpty) return false;
    if (_option!.isCustomCapacity) {
      return _customSpec != null && _customSpec!.isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShopElderUi.sectionTitle('🛒 常用物資'),
            if (_category == null)
              _buildCategories()
            else if (_selectedBrand == null)
              _buildBrands()
            else
              _buildCapacityStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final cats = ElderSupplyTemplates.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final c = cats[i];
            return Center(
              child: ElderCategoryCircle(
                emoji: ShopElderUi.emojiForCategory(c.key),
                label: c.label,
                onTap: () => _selectCategory(c),
              ),
            );
          },
        ),
      ],
    );
  }

  List<AssistantBrandChoice> _brandChoices(SupplyCategory cat) {
    final brands = ElderSupplyTemplates.distinctBrands(cat);
    return [
      for (var i = 0; i < brands.length; i++)
        AssistantBrandChoice(
          index: i + 1,
          optionId: brands[i].id,
          label: ElderSupplyTemplates.displayBrandLabel(brands[i].brand),
          subtitle: brands[i].isUnspecified
              ? '由志工依現場狀況代選'
              : (brands[i].isOther ? '請填寫指定品牌' : null),
          fallbackEmoji: ElderSupplyTemplates.emojiForCategoryKey(cat.key),
          sendMessageOnTap: '${i + 1}',
        ),
    ];
  }

  Widget _buildBrands() {
    final cat = _category!;
    return Column(
      key: _scrollTargetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _resetToCategories,
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '② 選${cat.label}品牌',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BrandChoiceList(
          choices: _brandChoices(cat),
          displayMode: BrandPickDisplayMode.brandOnly,
          onTapChoice: (c) {
            final opt = cat.options.firstWhere((o) => o.id == c.optionId);
            _selectBrand(opt.brand);
          },
        ),
      ],
    );
  }

  List<AssistantBrandChoice> _capacityChoices(SupplyCategory cat, String brand) {
    final variants = ElderSupplyTemplates.optionsForBrand(cat, brand);
    return [
      for (var i = 0; i < variants.length; i++)
        AssistantBrandChoice(
          index: i + 1,
          optionId: variants[i].id,
          label: variants[i].spec,
          priceHint: variants[i].refPrice != null
              ? '約 ${variants[i].refPrice!.toInt()} 元'
              : '請志工現場確認',
          fallbackEmoji: ElderSupplyTemplates.emojiForCategoryKey(cat.key),
          sendMessageOnTap: '${i + 1}',
        ),
    ];
  }

  Widget _buildCapacityStep() {
    final cat = _category!;
    final brand = _selectedBrand!;
    final isVolunteerPickBrand = brand == ElderSupplyTemplates.unspecifiedBrandLabel;
    final titleBrand = isVolunteerPickBrand
        ? ElderSupplyTemplates.volunteerPickBrandDisplayLabel
        : (_isOtherBrand
            ? ElderSupplyTemplates.otherBrandLabel
            : ElderSupplyTemplates.displayBrandLabel(brand));
    return Column(
      key: _scrollTargetKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => setState(() {
                _selectedBrand = null;
                _option = null;
                _customSpec = null;
                _customSpecController.clear();
              }),
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '③ 選容量 · $titleBrand',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isOtherBrand) ...[
          TextField(
            controller: _otherBrandController,
            style: const TextStyle(fontSize: 22),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '品牌名稱',
              hintText: '輸入想要的品牌',
              labelStyle: const TextStyle(fontSize: 18),
              hintStyle: const TextStyle(fontSize: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        BrandChoiceList(
          choices: _capacityChoices(cat, brand),
          displayMode: BrandPickDisplayMode.capacityOnly,
          promptText: '點選容量（或說 1、2、3）',
          onTapChoice: (c) {
            final variants = ElderSupplyTemplates.optionsForBrand(cat, brand);
            final opt = variants.firstWhere((o) => o.id == c.optionId);
            _selectCapacity(opt);
          },
        ),
        const SizedBox(height: 16),
        _CustomCapacityPanel(
          controller: _customSpecController,
          focusNode: _customSpecFocus,
          categoryKey: cat.key,
          volunteerPicksBrand: isVolunteerPickBrand,
          isSelected: _option?.isCustomCapacity == true,
          onConfirm: _confirmCustomSpec,
          onTapField: () {
            setState(() {
              _option = ElderSupplyTemplates.customCapacityPicker(cat, brand);
              _customSpec = null;
              _qty = 1;
            });
          },
        ),
        if (_canAddToDraft) ...[
          const SizedBox(height: 16),
          Card(
            key: _summaryAnchorKey,
            color: const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _summaryTitle(cat),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: '品牌',
                    value: _isOtherBrand
                        ? (_otherBrandController.text.trim().isEmpty
                            ? '請輸入品牌'
                            : _otherBrandController.text.trim())
                        : ElderSupplyTemplates.displayBrandLabel(_option!.brand),
                  ),
                  const SizedBox(height: 6),
                  _SummaryRow(label: '容量', value: _effectiveSpec ?? '—'),
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: '參考售價',
                    value: _option!.isCustomCapacity
                        ? '請志工現場確認'
                        : _option!.refPrice != null
                            ? '約 ${_option!.refPrice!.toInt()} 元'
                            : '請志工現場確認',
                    accent: !_option!.isCustomCapacity && _option!.refPrice != null,
                  ),
                  if (isVolunteerPickBrand)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '品牌由志工依現場狀況代選',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_isOtherBrand)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '已指定品牌，請確認容量無誤',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElderQtyBar(
            quantity: _qty,
            unitLabel: _option!.unitLabel,
            onDecrease: _qty > 1 ? () => setState(() => _qty--) : null,
            onIncrease: () => setState(() => _qty++),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addToDraft,
            icon: const Icon(Icons.add_shopping_cart, size: 28),
            label: const Text(
              '加入採買清單',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              backgroundColor: ShopElderUi.green,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addToDraft() async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    final otherBrand = _otherBrandController.text.trim();
    final snap = ElderSupplyTemplates.buildSnapshot(
      category: _category!,
      option: _option!,
      quantity: _qty,
      specOverride: _customSpec,
      brandOverride: _isOtherBrand && otherBrand.isNotEmpty ? otherBrand : null,
      referenceNote: _isOtherBrand && otherBrand.isNotEmpty ? otherBrand : null,
    );
    try {
      await ref.read(demandRecordsRepositoryProvider).addSnapshotLines(
            userId: uid,
            lines: [snap],
          );
      ref.invalidate(elderDemandDraftProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ 已加入：${snap.productName} × $_qty',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
      _resetToCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入失敗，請稍後再試。')),
      );
    }
  }
}

class _CustomCapacityPanel extends StatelessWidget {
  const _CustomCapacityPanel({
    required this.controller,
    required this.focusNode,
    required this.categoryKey,
    required this.volunteerPicksBrand,
    required this.isSelected,
    required this.onConfirm,
    required this.onTapField,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String categoryKey;
  final bool volunteerPicksBrand;
  final bool isSelected;
  final VoidCallback onConfirm;
  final VoidCallback onTapField;

  String get _hint => '輸入容量';

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? const Color(0xFFFFF8E1) : const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFFB300) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '✏️ 自己填容量',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              focusNode: focusNode,
              onTap: onTapField,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: _hint,
                hintStyle: const TextStyle(fontSize: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onConfirm(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline, size: 26),
              label: const Text(
                '確認容量',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: ShopElderUi.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent ? const Color(0xFF2E7D32) : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
