import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/assistant/data/assistant_shop_action_service.dart';
import 'package:smart_bp/features/shop/data/price_references_repository.dart';
import 'package:smart_bp/features/shop/presentation/shop_products_provider.dart';

final priceReferencesListProvider =
    FutureProvider.autoDispose<List<PriceReference>>((ref) async {
  final products = await ref.watch(shopProductsProvider.future);
  final repo = ref.watch(priceReferencesRepositoryProvider);
  await repo.seedFromProducts(products);
  return repo.listAll();
});

/// 全聯價格參考頁（第五章 5.3.1）。
class ShopPricePage extends ConsumerStatefulWidget {
  const ShopPricePage({super.key});

  @override
  ConsumerState<ShopPricePage> createState() => _ShopPricePageState();
}

class _ShopPricePageState extends ConsumerState<ShopPricePage> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(priceReferencesListProvider);
    final q = _search.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text(
          '全聯價格參考',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '搜尋商品名稱…',
                hintStyle: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, size: 28),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _green)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '讀取價格參考失敗：$e\n請確認已執行 chapter5_shop_assistant_schema.sql',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              data: (list) {
                final filtered = list.where((p) {
                  if (q.isEmpty) return true;
                  return p.productName.toLowerCase().contains(q) ||
                      (p.category ?? '').toLowerCase().contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('找不到符合的商品', style: TextStyle(fontSize: 20)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          p.productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          p.category ?? '一般',
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: Text(
                          p.unitPrice != null
                              ? '${p.unitPrice!.toStringAsFixed(0)} 元'
                              : '待更新',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
