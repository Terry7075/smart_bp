import 'package:flutter/material.dart';
import 'package:smart_bp/features/shop/data/shop_category_images.dart';

/// 柑仔店長輩端共用 UI：大字、大觸控區、圓形按鈕、橫向步驟。
abstract final class ShopElderUi {
  static const Color green = Color(0xFF2E7D32);
  static const Color brown = Color(0xFF5D4037);
  static const Color cream = Color(0xFFFFF8E1);

  static const _categoryEmoji = ShopCategoryImages.supplyEmojiByKey;

  static String emojiForCategory(String key) => _categoryEmoji[key] ?? '🛒';

  static Widget sectionGap([double h = 20]) => SizedBox(height: h);

  static Widget sectionTitle(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 16, height: 1.35, color: Colors.grey.shade800),
            ),
          ],
        ],
      ),
    );
  }
}

/// 橫向三步驟指引（避免直排擠在一起）。
class ElderStepRow extends StatelessWidget {
  const ElderStepRow({super.key, this.activeStep = 1});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const steps = ['① 填寫需求', '② 選品牌容量', '③ 送出'];
    return Card(
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: i < activeStep
                        ? ShopElderUi.green.withValues(alpha: 0.45)
                        : Colors.grey.shade300,
                  ),
                ),
              Expanded(
                flex: 2,
                child: _StepBubble(
                  label: steps[i],
                  active: i + 1 <= activeStep,
                  current: i + 1 == activeStep,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  const _StepBubble({
    required this.label,
    required this.active,
    required this.current,
  });

  final String label;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final bg = current
        ? ShopElderUi.green
        : active
            ? const Color(0xFFC8E6C9)
            : Colors.grey.shade200;
    final fg = current ? Colors.white : Colors.black87;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: current
                ? Border.all(color: const Color(0xFFFFB300), width: 3)
                : null,
          ),
          child: Text(
            label.substring(0, 1),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.substring(2),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            color: current ? ShopElderUi.green : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// 圓形品類捷徑（2 欄網格）。
class ElderCategoryCircle extends StatelessWidget {
  const ElderCategoryCircle({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F5E9) : Colors.white,
      shape: const CircleBorder(),
      elevation: selected ? 4 : 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 108,
          height: 108,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? ShopElderUi.green : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大字數量調整列（圓形 +/-）。
class ElderQtyBar extends StatelessWidget {
  const ElderQtyBar({
    super.key,
    required this.quantity,
    required this.unitLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.enabled = true,
  });

  final int quantity;
  final String unitLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundIconButton(
          icon: Icons.remove,
          onPressed: enabled ? onDecrease : null,
          color: Colors.grey.shade700,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                '$quantity',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
              ),
              Text(unitLabel, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.add,
          onPressed: enabled ? onIncrease : null,
          color: ShopElderUi.green,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null ? Colors.grey.shade300 : color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            size: 32,
            color: onPressed == null ? Colors.grey : color,
          ),
        ),
      ),
    );
  }
}

/// 採買清單品項卡（每項獨立一張，不擠在同一列）。
class ElderDraftItemCard extends StatelessWidget {
  const ElderDraftItemCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.quantity,
    required this.unitLabel,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final int quantity;
  final String unitLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElderQtyBar(
                    quantity: quantity,
                    unitLabel: unitLabel,
                    onDecrease: onDecrease,
                    onIncrease: onIncrease,
                    enabled: enabled,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '移除',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.delete_outline, size: 28),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    backgroundColor: const Color(0xFFFFEBEE),
                    foregroundColor: const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 大圓角主行動按鈕。
class ElderPrimaryButton extends StatelessWidget {
  const ElderPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.send_rounded,
    this.loading = false,
    this.highlight = false,
    this.tall = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;
  final bool highlight;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 30),
      label: Text(
        loading ? '送出中…' : label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: ShopElderUi.green,
        minimumSize: Size(double.infinity, tall ? 72 : 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
        side: highlight
            ? const BorderSide(color: Color(0xFFFFB300), width: 3)
            : BorderSide.none,
      ),
    );
  }
}
