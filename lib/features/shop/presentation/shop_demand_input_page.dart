import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_intent_classifier.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/shop/data/demand_records_repository.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_realtime_provider.dart';
import 'package:smart_bp/features/shop/presentation/widgets/shop_voice_demand_bar.dart';

final elderDemandDraftProvider =
    FutureProvider.autoDispose<DemandRecord?>((ref) async {
  final uid = ref.watch(authProvider)?.user.id;
  if (uid == null) return null;
  return ref.read(demandRecordsRepositoryProvider).getOrCreateDraft(userId: uid);
});

/// 需求單輸入頁（第五章 5.3.1）：文字／語音 → 三層意圖 → demand_records 草稿。
class ShopDemandInputPage extends ConsumerStatefulWidget {
  const ShopDemandInputPage({super.key});

  @override
  ConsumerState<ShopDemandInputPage> createState() => _ShopDemandInputPageState();
}

class _ShopDemandInputPageState extends ConsumerState<ShopDemandInputPage> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submitDraftToVolunteer(BuildContext context) async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    try {
      final orderId = await ref.read(demandRecordsRepositoryProvider).submitDraftToOrders(
            userId: uid,
            ordersRepo: ref.read(shopOrdersRepositoryProvider),
          );
      ref.invalidate(elderDemandDraftProvider);
      ref.invalidate(shopVolunteerOrdersProvider);
      ref.invalidate(shopElderOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已送出給志工（單號前 8 碼：${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}）')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗：$e')),
      );
    }
  }

  Future<void> _submitText() async {
    final raw = _text.text.trim();
    if (raw.isEmpty) return;
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;

    final classification = AssistantShopIntentClassifier.classify(raw);
    await ref.read(assistantShopActionServiceProvider).handle(
          classification: classification,
          userId: uid,
          snapshot: const AssistantSnapshot(),
        );
    _text.clear();
    ref.invalidate(elderDemandDraftProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已解析並更新需求草稿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(elderDemandDraftProvider);

    return RoleGuard(
      requiredRole: RoleGuardTarget.elder,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text(
            '需求單輸入',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              '可用文字或語音說出要買的東西，系統會自動記在草稿裡。',
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 12),
            const ShopVoiceDemandBar(autoApplyOnRelease: true),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              style: const TextStyle(fontSize: 20),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '例：我要買米和醬油',
                hintStyle: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _submitText,
              icon: const Icon(Icons.send, size: 26),
              label: const Text('解析並加入草稿', style: TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '目前草稿',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            draft.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                '讀取失敗：$e\n請執行 chapter5_shop_assistant_schema.sql',
                style: const TextStyle(fontSize: 17),
              ),
              data: (record) {
                final items = record?.activeItems ?? const [];
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('尚無項目', style: TextStyle(fontSize: 18)),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      for (final it in items)
                        ListTile(
                          title: Text(
                            it.productName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            '× ${it.quantity}',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _submitDraftToVolunteer(context),
              icon: const Icon(Icons.send, size: 26),
              label: const Text('送出草稿給志工', style: TextStyle(fontSize: 18)),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/shop'),
              icon: const Icon(Icons.storefront, size: 26),
              label: const Text('或到柑仔店選商品後送出', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
