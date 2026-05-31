import 'package:flutter/material.dart';

import '../../prescription/prescription_models.dart';

/// 長輩「看圖認藥」上方資訊區塊：藥名 + 外觀文字（純文字，不再畫示意藥丸）。
///
/// 之前畫的「彩色橢圓藥丸示意圖」會跟下方的真實藥典照片並存，造成長輩混淆：
/// 「我到底要對照哪一顆？」。從專案需求討論後決定**全面以藥典實際照片為主**，
/// 移除示意圖相關所有程式碼（[buildPillVisual] / [resolvePillColor] /
/// `_PillVisualCaption`）。
///
/// 此 widget 現在只負責「文字資訊」：時段提示、藥名、外觀特徵。
/// 藥典照片由 [DrugImageSection] 在頁面下方獨立顯示。
class MedicationIdentityCard extends StatelessWidget {
  const MedicationIdentityCard({
    super.key,
    required this.record,
    this.slotTime,
    this.compact = false,
  });

  final PrescriptionRecord record;
  final String? slotTime;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final medName = record.displayMedicationName;
    final appearance = record.displayPillHint;
    final hasMed = medName != null && medName.isNotEmpty;
    final hasAppearance = appearance.isNotEmpty;

    if (!hasMed && !hasAppearance) {
      return Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFFFFF3E0),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: const Text(
            '💊 掃描時若藥單有寫藥名或外觀，\n小幫手會幫您記下來對照喔。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: Color(0xFF5D4037),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 14 : 18,
        ),
        child: Column(
          children: [
            Text(
              slotTime != null && slotTime!.isNotEmpty
                  ? '⏰ $slotTime 請吃這些藥'
                  : '💊 本次要吃的藥',
              style: TextStyle(
                fontSize: compact ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
            if (hasMed) ...[
              const SizedBox(height: 12),
              Text(
                medName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),
            ],
            if (hasAppearance) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '外觀特徵：$appearance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '請對照下方藥典圖片與手中藥袋',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ] else if (hasMed) ...[
              const SizedBox(height: 8),
              const Text(
                '請對照下方藥典圖片與手中藥袋',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
