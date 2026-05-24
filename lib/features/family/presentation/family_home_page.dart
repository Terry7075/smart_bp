import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/family/data/family_links_repository.dart';
import 'package:smart_bp/features/family/presentation/family_providers.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';

/// 家屬關懷首頁：綁定長輩、查看代購進度。
class FamilyHomePage extends ConsumerStatefulWidget {
  const FamilyHomePage({super.key});

  @override
  ConsumerState<FamilyHomePage> createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends ConsumerState<FamilyHomePage> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _cream = Color(0xFFFFF8E1);

  final _elderIdCtrl = TextEditingController();
  final _relationCtrl = TextEditingController(text: '子女');

  @override
  void dispose() {
    _elderIdCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  Future<void> _bindElder() async {
    final uid = ref.read(authProvider)?.user.id;
    if (uid == null) return;
    final elderId = _elderIdCtrl.text.trim();
    if (elderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入長輩的使用者 ID（可向里幹部索取）')),
      );
      return;
    }
    try {
      await ref.read(familyLinksRepositoryProvider).bindElder(
            familyUserId: uid,
            elderUserId: elderId,
            relation: _relationCtrl.text.trim(),
          );
      ref.invalidate(familyLinksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已綁定長輩，可查看代購進度')),
      );
      _elderIdCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('綁定失敗：$e\n請確認已執行 graduation_enhancement_schema.sql')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(familyLinksProvider);

    return RoleGuard(
      requiredRole: RoleGuardTarget.family,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          title: const Text('家屬關懷', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _purple,
          onRefresh: () async => ref.invalidate(familyLinksProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.purple.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '綁定家中長輩後，可查看柑仔店代購進度，減少電話追問。',
                    style: TextStyle(fontSize: 17, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('新增綁定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _elderIdCtrl,
                decoration: const InputDecoration(
                  labelText: '長輩使用者 ID',
                  hintText: 'UUID（Demo 可向隊友索取）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _relationCtrl,
                decoration: const InputDecoration(
                  labelText: '稱謂',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _bindElder,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('綁定長輩', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              const Text('已綁定長輩', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              links.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('讀取失敗：$e'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Text('尚無綁定，請先新增。', style: TextStyle(fontSize: 18));
                  }
                  return Column(
                    children: [
                      for (final link in list)
                        _ElderLinkCard(link: link),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElderLinkCard extends ConsumerWidget {
  const _ElderLinkCard({required this.link});

  final FamilyElderLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(familyElderOrdersProvider(link.elderUserId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              link.elderName ?? '長輩',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('關係：${link.relation}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            orders.when(
              loading: () => const Text('讀取訂單中…'),
              error: (e, _) => Text('訂單：$e'),
              data: (list) {
                if (list.isEmpty) {
                  return const Text('尚無代購需求單', style: TextStyle(fontSize: 16));
                }
                final latest = list.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近：${ShopOrderStatus.orderStatusLabel(latest.status)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => context.push('/shop/orders/${latest.id}'),
                      icon: const Icon(Icons.timeline),
                      label: const Text('查看配送進度'),
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
