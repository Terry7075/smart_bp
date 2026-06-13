import 'package:flutter/material.dart';
import 'package:smart_bp/features/shop/data/community_procurement_day.dart';

/// 柑仔店頂部：每週四統一採購日提醒。
class ProcurementDayBanner extends StatelessWidget {
  const ProcurementDayBanner({super.key});

  static const _orange = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF3E0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _orange, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_available, color: _orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                CommunityProcurementDay.flowBannerText(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: Color(0xFFBF360C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
