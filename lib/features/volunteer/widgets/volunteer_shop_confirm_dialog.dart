import 'package:flutter/material.dart';
import 'package:smart_bp/features/shared/elder_phone_utils.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/data/elder_supply_templates.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// 志工／長輩物資代購：高風險動作二次確認。
abstract final class VolunteerShopConfirmDialog {
  static Future<bool> launchTel(BuildContext context, String? raw) async {
    final dial = ElderPhoneUtils.normalizeForDial(raw);
    if (dial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('尚無長輩聯絡電話')),
      );
      return false;
    }
    final uri = Uri(scheme: 'tel', path: dial);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('無法開啟撥號：${ElderPhoneUtils.formatForDisplay(dial) ?? dial}')),
    );
    return false;
  }

  /// 志工撥打長輩：先讀 profiles 最新電話，再 fallback 快取號碼。
  static Future<bool> launchTelForElder(
    BuildContext context, {
    required String elderUserId,
    String? fallbackPhone,
  }) async {
    final latest = await ElderPhoneUtils.fetchLatestPhone(elderUserId);
    final phone = latest ?? fallbackPhone;
    if (!context.mounted) return false;
    return launchTel(context, phone);
  }

  /// 志工代長輩送出 draft → 正式需求單。
  static Future<bool> confirmSubmitDraftOnBehalf(
    BuildContext context, {
    required DemandRecord draft,
  }) async {
    var phoneConfirmed = false;
    final elderName = (draft.elderDisplayName ?? '').trim().isNotEmpty
        ? draft.elderDisplayName!.trim()
        : '長輩';
    final items = draft.activeItems;
    final summary = items
        .map(
          (i) => ElderSupplyTemplates.formatDraftLineSummary(
            productName: i.productName,
            brand: i.brand,
            spec: i.spec,
            quantity: i.quantity,
            unitLabel: i.unitLabel,
          ),
        )
        .join('\n');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text(
              '代長輩送出需求單？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    elderName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (draft.elderPhone != null &&
                      draft.elderPhone!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '電話：${ElderPhoneUtils.formatForDisplay(draft.elderPhone) ?? draft.elderPhone}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  if (draft.locationName != null &&
                      draft.locationName!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '據點：${draft.locationName}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '品項摘要：',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items.isEmpty ? '（無品項）' : summary,
                    style: const TextStyle(fontSize: 16, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '送出後會建立正式需求單，志工可於下方「已送出需求單」接單代購。\n'
                    '請先電話確認長輩同意代為送出。',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: draft.userId.trim().isEmpty
                        ? null
                        : () async {
                            await launchTelForElder(
                              ctx,
                              elderUserId: draft.userId,
                              fallbackPhone: draft.elderPhone,
                            );
                          },
                    icon: const Icon(Icons.call, size: 22),
                    label: const Text(
                      '致電長輩確認',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: phoneConfirmed,
                    onChanged: (v) => setState(() => phoneConfirmed = v == true),
                    title: const Text(
                      '我已電話確認長輩同意代為送出',
                      style: TextStyle(fontSize: 15),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('先不要', style: TextStyle(fontSize: 16)),
              ),
              FilledButton(
                onPressed: phoneConfirmed ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                ),
                child: const Text(
                  '確認送出',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
    return result == true;
  }

  static Future<bool> confirmCompleteDelivery(
    BuildContext context, {
    required String elderName,
    required String itemSummary,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('完成這位長輩的採購？'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              elderName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              itemSummary,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '將通知長輩：物資已經送到活動中心囉。',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先不要'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
            child: const Text('確認完成'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> confirmMilestone(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 16, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> confirmBatchAccept(
    BuildContext context, {
    required int orderCount,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全部接單？'),
        content: Text(
          '將 $orderCount 筆待接單需求全部改為「已接單」，並通知長輩將於下次採購日代買。',
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先不要'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
            child: const Text('確認接單'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> confirmBatchProcuring(
    BuildContext context, {
    required int orderCount,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('標記採買中？'),
        content: Text(
          '將 $orderCount 筆已接單需求標記為「採買中」。',
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先不要'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Color(0xFF1565C0)),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static Future<bool> confirmBatchCompleteDelivery(
    BuildContext context, {
    required List<ShopOrderListRow> orders,
  }) async {
    String elderLabel(ShopOrderListRow o) {
      final name = (o.elderDisplayName ?? '').trim();
      if (name.isNotEmpty) return name;
      return '長輩 ${o.userId.substring(0, 8)}…';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全部完成採購？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '將通知以下 ${orders.length} 位長輩物資已送達活動中心：',
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 12),
              for (final o in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person_outline,
                          size: 20, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          elderLabel(o),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先不要'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
            child: const Text('確認全部完成'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 長輩柑仔店「送出給志工」。確認則回傳備註（可為空字串）；取消回傳 null。
  static Future<String?> confirmElderSubmit(
    BuildContext context, {
    required int itemCount,
    required String itemsSummary,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ElderSubmitDialog(
        itemCount: itemCount,
        itemsSummary: itemsSummary,
      ),
    );
  }
}

class _ElderSubmitDialog extends StatefulWidget {
  const _ElderSubmitDialog({
    required this.itemCount,
    required this.itemsSummary,
  });

  final int itemCount;
  final String itemsSummary;

  @override
  State<_ElderSubmitDialog> createState() => _ElderSubmitDialogState();
}

class _ElderSubmitDialogState extends State<_ElderSubmitDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '確認送出給志工？',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '共 ${widget.itemCount} 項：\n${widget.itemsSummary}',
              style: const TextStyle(fontSize: 18, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: '備註（選填）',
                labelStyle: const TextStyle(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '送出後志工會收到通知並協助代購。',
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('再想想', style: TextStyle(fontSize: 17)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _noteController.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
          child: const Text('確認送出', style: TextStyle(fontSize: 17)),
        ),
      ],
    );
  }
}
