import '../prescription/prescription_models.dart';

/// 10 天寬限期內、依「同一個領藥日」分群的一筆代領項目。
class BatchRefillElderItem {
  const BatchRefillElderItem({
    required this.prescription,
    required this.elderName,
  });

  final PrescriptionRecord prescription;
  final String elderName;

  /// 點開細節時顯示用：未填院所改成「（未填醫療機構）」避免 UI 空字串。
  String get hospitalDisplay {
    final h = prescription.hospitalName?.trim();
    if (h == null || h.isEmpty) return '（未填醫療機構）';
    return h;
  }
}

/// 同一個領藥日的一批代領任務。
///
/// 為什麼從「依醫療機構分群」改成「依領藥日分群」？
/// - 志工真正的痛點是「哪一天要出門代領」，不是「哪一家藥局」；同一天有
///   多份藥單（不同長輩、不同藥局）統合在一張卡上，可以一眼看到當天負擔。
/// - 同一張卡裡每位長輩仍會顯示自己的藥局／藥名，點進去可以看完整原始藥單。
class BatchRefillGroup {
  const BatchRefillGroup({
    required this.pickupDate,
    required this.items,
  });

  /// 此卡片代表的「領藥日」（純日期、00:00）。
  final DateTime pickupDate;

  /// 排序後的代領項目（多名長輩可同一天）。
  final List<BatchRefillElderItem> items;

  int get count => items.length;

  bool get allHealthCardsCollected =>
      items.isNotEmpty && items.every((e) => e.prescription.hasHealthCard);

  /// 卡片標題顯示用：`yyyy/MM/dd（週幾）`。週幾用中文一個字，給長輩 / 志工
  /// 都看得懂。
  String get titleDisplay {
    final y = pickupDate.year.toString();
    final m = pickupDate.month.toString().padLeft(2, '0');
    final d = pickupDate.day.toString().padLeft(2, '0');
    return '$y/$m/$d（${_weekdayLabel(pickupDate.weekday)}）';
  }

  static String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '週一';
      case DateTime.tuesday:
        return '週二';
      case DateTime.wednesday:
        return '週三';
      case DateTime.thursday:
        return '週四';
      case DateTime.friday:
        return '週五';
      case DateTime.saturday:
        return '週六';
      case DateTime.sunday:
        return '週日';
      default:
        return '';
    }
  }
}

/// 將藥單列表過濾並依「領藥日」分群（純函式，方便單元測試）。
///
/// 規則：
///   1. 只保留 `status='active'` 且 `pickup_date` 有值的藥單
///   2. `pickup_date - today` 在 10 天寬限期內（含當天、含已過期）
///   3. 同日的多份藥單會 sort 在同一個 [BatchRefillGroup] 內，
///      group 內再依「醫療機構 + 長輩姓名 + id」排序，保持 UI 穩定
///   4. 多個 group 之間依日期由近到遠排序（最緊急的當天 / 過期的在最上）
List<BatchRefillGroup> groupPrescriptionsForBatchRefill({
  required List<PrescriptionRecord> prescriptions,
  required Map<String, String> elderNamesByUserId,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final todayOnly = DateTime(now.year, now.month, now.day);

  // --- 過濾：有效藥單或「長輩已刪除但志工仍需確認」+ 有領藥日 + 10 天寬限期內 ---
  final eligible = prescriptions.where((rx) {
    final pickup = rx.pickupDate;
    if (pickup == null) return false;
    final pickupOnly = DateTime(pickup.year, pickup.month, pickup.day);
    final daysUntil = pickupOnly.difference(todayOnly).inDays;
    if (daysUntil > 10) return false;

    if (RefillStatus.isPrescriptionDeletedByElder(rx.refillStatus)) {
      return true;
    }
    if (!rx.isManageablePrescription) return false;
    return true;
  }).toList();

  // --- 依「領藥日（純日期）」分群 ---
  final grouped = <DateTime, List<BatchRefillElderItem>>{};
  for (final rx in eligible) {
    final pickup = rx.pickupDate!;
    final dateKey = DateTime(pickup.year, pickup.month, pickup.day);

    final elderName =
        elderNamesByUserId[rx.userId]?.trim().isNotEmpty == true
            ? elderNamesByUserId[rx.userId]!.trim()
            : '長輩';

    grouped.putIfAbsent(dateKey, () => []).add(
          BatchRefillElderItem(
            prescription: rx,
            elderName: elderName,
          ),
        );
  }

  // --- 卡片內排序：醫療機構 → 長輩名字 → 藥單 id（保持穩定） ---
  for (final list in grouped.values) {
    list.sort((a, b) {
      final ha = a.prescription.hospitalName?.trim() ?? '';
      final hb = b.prescription.hospitalName?.trim() ?? '';
      final hospitalCmp = ha.compareTo(hb);
      if (hospitalCmp != 0) return hospitalCmp;
      final nameCmp = a.elderName.compareTo(b.elderName);
      if (nameCmp != 0) return nameCmp;
      return a.prescription.id.compareTo(b.prescription.id);
    });
  }

  // --- 卡片之間排序：日期由近到遠 ---
  final dateKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

  return [
    for (final key in dateKeys)
      BatchRefillGroup(pickupDate: key, items: grouped[key]!),
  ];
}
