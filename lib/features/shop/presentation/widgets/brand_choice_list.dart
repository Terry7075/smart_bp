import 'package:flutter/material.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';

enum BrandChoiceLayout { list, grid }

/// 品牌卡顯示模式：完整 / 僅品牌 / 僅容量（含價格）。
enum BrandPickDisplayMode { full, brandOnly, capacityOnly }

/// 品牌圖文選項（小幫手與柑仔店 wizard 共用）。
class BrandChoiceList extends StatelessWidget {
  const BrandChoiceList({
    super.key,
    required this.choices,
    this.onTapChoice,
    this.enabled = true,
    this.layout = BrandChoiceLayout.list,
    this.displayMode = BrandPickDisplayMode.full,
    this.promptText,
  });

  final List<AssistantBrandChoice> choices;
  final void Function(AssistantBrandChoice choice)? onTapChoice;
  final bool enabled;
  final BrandChoiceLayout layout;
  final BrandPickDisplayMode displayMode;
  final String? promptText;

  String get _defaultPrompt => switch (displayMode) {
        BrandPickDisplayMode.brandOnly => '點選品牌（或說 1、2、3）',
        BrandPickDisplayMode.capacityOnly => '點選容量（或說 1、2、3）',
        BrandPickDisplayMode.full => '點選品牌（或說 1、2、3）',
      };

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            promptText ?? _defaultPrompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Color(0xFF5D4037)),
          ),
        ),
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ElderBrandPickCard(
              choice: c,
              onTap: onTapChoice,
              enabled: enabled,
              displayMode: displayMode,
            ),
          ),
      ],
    );
  }
}

/// 長輩友善品牌卡：直向排列，容量與參考售價分開顯示。
class ElderBrandPickCard extends StatelessWidget {
  const ElderBrandPickCard({
    super.key,
    required this.choice,
    this.onTap,
    required this.enabled,
    this.displayMode = BrandPickDisplayMode.full,
  });

  final AssistantBrandChoice choice;
  final void Function(AssistantBrandChoice choice)? onTap;
  final bool enabled;
  final BrandPickDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final label = '${choice.index}. ${choice.label}';
    final spec = (choice.subtitle ?? '').trim();
    final price = (choice.priceHint ?? '').trim();
    final showSpec =
        displayMode == BrandPickDisplayMode.full && spec.isNotEmpty;
    final showPrice =
        displayMode != BrandPickDisplayMode.brandOnly && price.isNotEmpty;
    final showVolunteerHint = displayMode == BrandPickDisplayMode.brandOnly &&
        (choice.subtitle ?? '').trim().isEmpty &&
        spec.isEmpty &&
        price.isEmpty &&
        choice.label.contains(ElderSupplyTemplates.volunteerPickBrandDisplayLabel);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: enabled && onTap != null ? () => onTap!(choice) : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _ChoiceImage(
                        url: choice.imageUrl,
                        fallbackEmoji: choice.fallbackEmoji,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const Icon(Icons.touch_app, size: 30, color: Color(0xFF5D4037)),
                ],
              ),
              if (displayMode == BrandPickDisplayMode.brandOnly &&
                  (choice.subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  choice.subtitle!.trim(),
                  style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
                ),
              ],
              if (showSpec || showPrice) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
              if (showSpec)
                _InfoBlock(
                  icon: Icons.inventory_2_outlined,
                  label: displayMode == BrandPickDisplayMode.capacityOnly
                      ? '容量'
                      : '容量',
                  value: spec,
                ),
              if (showSpec && showPrice) const SizedBox(height: 10),
              if (showPrice)
                _InfoBlock(
                  icon: Icons.sell_outlined,
                  label: '參考售價',
                  value: price,
                  accent: true,
                ),
              if (showVolunteerHint)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '下一步再選容量',
                    style: TextStyle(fontSize: 17, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5);
    final fg = accent ? const Color(0xFF2E7D32) : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceImage extends StatelessWidget {
  const _ChoiceImage({this.url, this.fallbackEmoji});

  final String? url;
  final String? fallbackEmoji;

  @override
  Widget build(BuildContext context) {
    final emoji = (fallbackEmoji ?? '🛒').trim().isEmpty ? '🛒' : fallbackEmoji!.trim();
    final networkUrl = url?.trim();
    final useEmojiOnly = fallbackEmoji != null && fallbackEmoji!.trim().isNotEmpty;

    // 常用物資品牌卡：Demo 一律用離線 emoji，不載 Flaticon（避免載到錯誤占位圖）。
    if (useEmojiOnly) {
      return ColoredBox(
        color: const Color(0xFFE8F5E9),
        child: _EmojiTile(emoji: emoji),
      );
    }

    return ColoredBox(
      color: const Color(0xFFE8F5E9),
      child: networkUrl != null && networkUrl.isNotEmpty
          ? Image.network(
              networkUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _EmojiTile(emoji: emoji),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _EmojiTile(emoji: emoji);
              },
            )
          : _EmojiTile(emoji: emoji),
    );
  }
}

class _EmojiTile extends StatelessWidget {
  const _EmojiTile({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 40, height: 1),
      ),
    );
  }
}
