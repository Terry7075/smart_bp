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
  return repo.listWithFallback();
});

/// 常用品項參考價頁（第五章 5.3.1）。
class ShopPricePage extends ConsumerStatefulWidget {
  const ShopPricePage({super.key, this.initialQuery});

  /// 從小幫手帶入的搜尋關鍵字（例如 `衛生紙`）。
  final String? initialQuery;

  @override
  ConsumerState<ShopPricePage> createState() => _ShopPricePageState();
}

class _ShopPricePageState extends ConsumerState<ShopPricePage> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _cream = Color(0xFFFFF8E1);

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _search.text = q;
    }
  }

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
          '常用品參考價',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '價格由社區志工依全聯門市常見品項人工整理，僅供參考；'
              '實際以志工採買當日門市為準。',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        q.isEmpty
                            ? '尚無價格資料，請稍後再試'
                            : '找不到「$q」相關商品\n可改搜尋「米」「鮮奶」或到柑仔店看完整目錄',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, height: 1.4),
                      ),
                    ),
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
                          [
                            if (p.category != null && p.category!.isNotEmpty)
                              p.category!,
                            if (p.displaySourceNote != null &&
                                p.displaySourceNote!.isNotEmpty)
                              p.displaySourceNote!,
                          ].join(' · '),
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
