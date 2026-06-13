import 'package:flutter/material.dart';
import 'package:smart_bp/features/assistant/domain/assistant_brand_choice.dart';

/// 品牌圖文選項（小幫手與柑仔店 wizard 共用）。
class BrandChoiceList extends StatelessWidget {
  const BrandChoiceList({
    super.key,
    required this.choices,
    this.onTapChoice,
    this.enabled = true,
  });

  final List<AssistantBrandChoice> choices;
  final void Function(AssistantBrandChoice choice)? onTapChoice;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '點選或說 1、2、3',
            style: TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
          ),
        ),
        for (final c in choices) _BrandCard(choice: c, onTap: onTapChoice, enabled: enabled),
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.choice,
    this.onTap,
    required this.enabled,
  });

  final AssistantBrandChoice choice;
  final void Function(AssistantBrandChoice choice)? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final label = '${choice.index}. ${choice.label}';
    final semantics = StringBuffer(label);
    if (choice.subtitle != null) semantics.write('，${choice.subtitle}');
    if (choice.priceHint != null) semantics.write('，${choice.priceHint}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: semantics.toString(),
        button: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          child: InkWell(
            onTap: enabled && onTap != null ? () => onTap!(choice) : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: _ChoiceImage(url: choice.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (choice.subtitle != null)
                          Text(
                            choice.subtitle!,
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        if (choice.priceHint != null)
                          Text(
                            choice.priceHint!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceImage extends StatelessWidget {
  const _ChoiceImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFEFEBE9),
        child: Icon(Icons.shopping_bag_outlined, size: 36, color: Color(0xFF8D6E63)),
      );
    }
    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFEFEBE9),
        child: Icon(Icons.shopping_bag_outlined, size: 36, color: Color(0xFF8D6E63)),
      ),
    );
  }
}
