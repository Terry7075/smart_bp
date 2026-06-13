/// 小幫手品牌追問的圖文選項卡。
class AssistantBrandChoice {
  const AssistantBrandChoice({
    required this.index,
    required this.optionId,
    required this.label,
    this.subtitle,
    this.priceHint,
    this.imageUrl,
    this.sendMessageOnTap,
  });

  final int index;
  final String optionId;
  final String label;
  final String? subtitle;
  final String? priceHint;
  final String? imageUrl;
  final String? sendMessageOnTap;

  Map<String, dynamic> toJson() => {
        'index': index,
        'option_id': optionId,
        'label': label,
        if (subtitle != null) 'subtitle': subtitle,
        if (priceHint != null) 'price_hint': priceHint,
        if (imageUrl != null) 'image_url': imageUrl,
        if (sendMessageOnTap != null) 'send_message_on_tap': sendMessageOnTap,
      };

  factory AssistantBrandChoice.fromJson(Map<String, dynamic> json) {
    return AssistantBrandChoice(
      index: (json['index'] as num?)?.toInt() ?? 1,
      optionId: json['option_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      priceHint: json['price_hint']?.toString(),
      imageUrl: json['image_url']?.toString(),
      sendMessageOnTap: json['send_message_on_tap']?.toString(),
    );
  }
}
