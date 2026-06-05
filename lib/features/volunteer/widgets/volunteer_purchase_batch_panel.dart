import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/presentation/shop_intelligence_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 志工：智慧合併採買批次（路線規劃已下架，改「今日採買清單」Tab）。
class VolunteerPurchaseBatchPanel extends ConsumerStatefulWidget {
  const VolunteerPurchaseBatchPanel({super.key});

  @override
  ConsumerState<VolunteerPurchaseBatchPanel> createState() =>
      _VolunteerPurchaseBatchPanelState();
}

class _VolunteerPurchaseBatchPanelState
    extends ConsumerState<VolunteerPurchaseBatchPanel> {
  bool _busy = false;

  Future<void> _createBatch() async {
    final userId = ref.read(authProvider)?.user.id;
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(purchaseBatchRepositoryProvider);
      final locId = await const DemandRecordsRepository()
          .fetchElderLocationPointId(userId);
      final locationPointId = locId ?? await _defaultLocationPointId() ?? '';
      if (locationPointId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先在後台設定據點')),
        );
        return;
      }
      await repo.createBatchFromLocation(
        volunteerId: userId,
        locationPointId: locationPointId,
      );
      ref.invalidate(volunteerPurchaseBatchesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          content: Text('已建立合併採買批次'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('建立批次失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _defaultLocationPointId() async {
    try {
      final row = await Supabase.instance.client
          .from('location_points')
          .select('id')
          .limit(1)
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(volunteerPurchaseBatchesProvider);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '智慧合併採買批次',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '同據點需求自動合併數量。採買請用上方「今日採買清單」。',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _createBatch,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_type),
              label: const Text('建立本週採買批次', style: TextStyle(fontSize: 17)),
            ),
            const SizedBox(height: 12),
            batches.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('讀取批次失敗：$e', style: const TextStyle(fontSize: 15)),
              data: (list) {
                if (list.isEmpty) {
                  return const Text('尚無批次', style: TextStyle(fontSize: 15));
                }
                return Column(
                  children: [
                    for (final b in list.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '批次 ${b.id.substring(0, 8)}… · ${b.status}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          b.lines
                              .map((l) =>
                                  '${l.brandLabel ?? ""}${l.categoryLabel}×${l.aggregatedQuantity}')
                              .join('、'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Text(
                          '${b.lines.length} 品項',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
