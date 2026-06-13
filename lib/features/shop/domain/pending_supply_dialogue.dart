/// 小幫手／柑仔店多輪代購槽位狀態。
enum SupplyDialogueStep {
  awaitBrand,
  awaitCapacity,
  awaitCustomCapacity,
  awaitQty,
  awaitOtherNote,
}

final class PendingSupplyDialogue {
  const PendingSupplyDialogue({
    required this.categoryKey,
    required this.categoryLabel,
    required this.quantity,
    this.unitLabel,
    this.rawUtterance,
    this.step = SupplyDialogueStep.awaitBrand,
    this.selectedOptionId,
    this.selectedBrand,
    this.categoryImageUrl,
  });

  final String categoryKey;
  final String categoryLabel;
  final int quantity;
  final String? unitLabel;
  final String? rawUtterance;
  final SupplyDialogueStep step;
  final String? selectedOptionId;
  final String? selectedBrand;
  final String? categoryImageUrl;

  PendingSupplyDialogue copyWith({
    SupplyDialogueStep? step,
    String? selectedOptionId,
    String? selectedBrand,
    int? quantity,
    String? unitLabel,
  }) {
    return PendingSupplyDialogue(
      categoryKey: categoryKey,
      categoryLabel: categoryLabel,
      quantity: quantity ?? this.quantity,
      unitLabel: unitLabel ?? this.unitLabel,
      rawUtterance: rawUtterance,
      step: step ?? this.step,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
      selectedBrand: selectedBrand ?? this.selectedBrand,
      categoryImageUrl: categoryImageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_key': categoryKey,
        'category_label': categoryLabel,
        'quantity': quantity,
        if (unitLabel != null) 'unit_label': unitLabel,
        if (rawUtterance != null) 'raw_utterance': rawUtterance,
        'step': step.name,
        if (selectedOptionId != null) 'selected_option_id': selectedOptionId,
        if (selectedBrand != null) 'selected_brand': selectedBrand,
        if (categoryImageUrl != null) 'category_image_url': categoryImageUrl,
      };

  factory PendingSupplyDialogue.fromJson(Map<String, dynamic> json) {
    final stepName = json['step']?.toString() ?? 'awaitBrand';
    final step = SupplyDialogueStep.values.firstWhere(
      (s) => s.name == stepName,
      orElse: () => SupplyDialogueStep.awaitBrand,
    );
    return PendingSupplyDialogue(
      categoryKey: json['category_key']?.toString() ?? '',
      categoryLabel: json['category_label']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitLabel: json['unit_label']?.toString(),
      rawUtterance: json['raw_utterance']?.toString(),
      step: step,
      selectedOptionId: json['selected_option_id']?.toString(),
      selectedBrand: json['selected_brand']?.toString(),
      categoryImageUrl: json['category_image_url']?.toString(),
    );
  }
}
