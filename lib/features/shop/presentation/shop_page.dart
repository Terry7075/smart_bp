import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:smart_bp/features/shop/data/image_proxy.dart';
import 'package:smart_bp/features/shop/data/px_search_thumb_client.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';
import 'package:smart_bp/features/shop/presentation/shop_products_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  static const Color _accentBrown = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final async = ref.watch(shopProductsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        title: const Text(
          '柑仔店',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('載入商品資料失敗\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (products) => _ShopOrderView(
          products: products,
          colorScheme: colorScheme,
          accent: _accentBrown,
        ),
      ),
    );
  }
}

class _ShopOrderView extends StatefulWidget {
  const _ShopOrderView({
    required this.products,
    required this.colorScheme,
    required this.accent,
  });

  final List<ShopProduct> products;
  final ColorScheme colorScheme;
  final Color accent;

  @override
  State<_ShopOrderView> createState() => _ShopOrderViewState();
}

class _ShopOrderViewState extends State<_ShopOrderView> {
  late final Map<String, int> _quantities;
  final _searchController = TextEditingController();
  String _search = '';
  String _selectedCategory = '全部';
  int _visibleCount = 24;

  @override
  void initState() {
    super.initState();
    _quantities = {for (final p in widget.products) p.id: 0};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeQty(String id, int delta) {
    final current = _quantities[id] ?? 0;
    setState(() => _quantities[id] = (current + delta).clamp(0, 999));
  }

  int get _totalCount => _quantities.values.fold(0, (sum, qty) => sum + qty);

  double get _totalAmount {
    var total = 0.0;
    for (final p in widget.products) {
      final qty = _quantities[p.id] ?? 0;
      if (p.unitPrice != null && qty > 0) total += p.unitPrice! * qty;
    }
    return total;
  }

  void _submitOrder() {
    if (_totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先選擇至少一項商品數量')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已建立訂購單（示範）：$_totalCount 項，合計 NT\$${_totalAmount.toStringAsFixed(0)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{for (final p in widget.products) p.category}.toList()..sort();
    final filtered = widget.products.where((p) {
      final q = _search.trim().toLowerCase();
      final byKeyword = q.isEmpty || p.name.toLowerCase().contains(q) || (p.spec?.toLowerCase().contains(q) ?? false);
      final byCategory = _selectedCategory == '全部' || p.category == _selectedCategory;
      return byKeyword && byCategory;
    }).toList();
    final visible = filtered.take(_visibleCount).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _search = value;
                  _visibleCount = 24;
                }),
                decoration: InputDecoration(
                  hintText: '搜尋商品名稱或規格',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryChip(
                      label: '全部',
                      selected: _selectedCategory == '全部',
                      onTap: () => setState(() {
                        _selectedCategory = '全部';
                        _visibleCount = 24;
                      }),
                    ),
                    for (final category in categories)
                      _CategoryChip(
                        label: category,
                        selected: _selectedCategory == category,
                        onTap: () => setState(() {
                          _selectedCategory = category;
                          _visibleCount = 24;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('共 ${filtered.length} 件商品', style: TextStyle(color: widget.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1400 ? 4 : (width >= 1000 ? 3 : 2);
                  const gridSpacing = 12.0;
                  final cellWidth =
                      (width - gridSpacing * (crossAxisCount - 1)).clamp(0.0, double.infinity) /
                      crossAxisCount;
                  // 主圖 1:1（約 cellWidth − 左右 padding），下方為品名／價格／按鈕。
                  // childAspectRatio = 寬／高 → 數值愈「小」格子愈高；reserve 含大字體與原價列緩衝。
                  final textScaler = MediaQuery.textScalerOf(context);
                  final scaleBump =
                      ((textScaler.scale(14) / 14).clamp(1.0, 2.2) - 1.0) * 96.0;
                  final belowImageReserve = 278.0 + scaleBump;
                  final childAspectRatio = cellWidth / (cellWidth + belowImageReserve);
                  return GridView.builder(
                    itemCount: visible.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                      childAspectRatio: childAspectRatio,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final p = visible[index];
                      return _ProductCard(
                        product: p,
                        accent: widget.accent,
                        quantity: _quantities[p.id] ?? 0,
                        onAdd: () => _changeQty(p.id, 1),
                        onRemove: () => _changeQty(p.id, -1),
                      );
                    },
                  );
                },
              ),
              if (filtered.length > visible.length)
                Center(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _visibleCount += 24),
                    child: Text('載入更多 (${filtered.length - visible.length} 筆)'),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(child: Text('$_totalCount 項\nNT\$${_totalAmount.toStringAsFixed(0)}')),
                FilledButton(onPressed: _submitOrder, child: const Text('送出訂購')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.accent,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final ShopProduct product;
  final Color accent;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  static final Uri _pxMartHomeUri = Uri.parse(
    'https://pxbox.es.pxmart.com.tw/?openExternalBrowser=1&utm_source=google&utm_medium=md_cpc&utm_campaign=brand_main_conv_2603&utm_content=260328-260507_normal&gad_source=1',
  );

  @override
  Widget build(BuildContext context) {
    final priceText = product.unitPrice != null ? 'NT\$${product.unitPrice!.toStringAsFixed(0)}' : '價格請以門市為準';
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _ShopProductImage(product: product),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$priceText${product.unitLabel != null ? '／${product.unitLabel}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    if (product.originalPrice != null && product.originalPrice != product.unitPrice)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '原價 NT\$${product.originalPrice!.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: quantity > 0 ? onRemove : null,
                              style: OutlinedButton.styleFrom(minimumSize: const Size(34, 30), padding: EdgeInsets.zero),
                              child: const Text('－'),
                            ),
                            const SizedBox(width: 6),
                            Text('$quantity'),
                            const SizedBox(width: 6),
                            FilledButton(
                              onPressed: onAdd,
                              style: FilledButton.styleFrom(minimumSize: const Size(34, 30), padding: EdgeInsets.zero),
                              child: const Text('＋'),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: product.sourceUrl == null ? null : () => _openProductUrl(context, product),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('全聯搜尋', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                        TextButton(
                          onPressed: () => _showProductDetail(context, product),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('詳情'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openProductUrl(BuildContext context, ShopProduct product) async {
    // 需求改為：直接導向全聯搜尋結果，避免過期 product URL 漂移到錯誤商品。
    final searchUri = _buildPxSearchUri(product);
    final openedSearch = await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    if (openedSearch) {
      return;
    }

    final openedHome = await launchUrl(_pxMartHomeUri, mode: LaunchMode.externalApplication);
    if (!openedHome && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯電商頁面，請稍後再試')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品連結失效，已改導向全聯首頁')),
      );
    }
  }

  static Uri _buildPxSearchUri(ShopProduct product) {
    final keyword = _buildSearchKeyword(product);
    return Uri.https('pxbox.es.pxmart.com.tw', '/search/result', {'keyword': keyword});
  }

  static String _buildSearchKeyword(ShopProduct product) => product.pxMartSearchKeyword;

  static Future<void> _showProductDetail(BuildContext context, ShopProduct product) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (product.promoText != null && product.promoText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(product.promoText!),
            ],
            if (product.sourceUrl != null && product.sourceUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openProductUrl(context, product),
                child: Text(
                  product.sourceUrl!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: product.sourceUrl!));
                },
                child: const Text('複製網址'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 若編譯時有設定 [PX_SEARCH_THUMB_API]：**只**顯示全聯搜尋縮圖；API 失敗或圖載不入則占位，**不用**種子 `imgURL`。
/// 未設定 API 時：先種子圖，載入失敗才打全聯縮圖（API 仍空則占位）。
class _ShopProductImage extends StatefulWidget {
  const _ShopProductImage({required this.product});

  final ShopProduct product;

  @override
  State<_ShopProductImage> createState() => _ShopProductImageState();
}

class _ShopProductImageState extends State<_ShopProductImage> {
  static const Color _photoBg = Color(0xFFF8F8F8);

  static String get _thumbApiBase => const String.fromEnvironment('PX_SEARCH_THUMB_API');

  bool get _preferPxThumb => _thumbApiBase.isNotEmpty;

  String? _url;
  bool _loadingPx = false;
  /// 未開「僅全聯」模式時，是否已因種子破圖而改打全聯。
  bool _pxFetchStarted = false;

  @override
  void initState() {
    super.initState();
    if (_preferPxThumb) {
      _pxFetchStarted = true;
      _loadPxThumbFirst();
      return;
    }
    _applySeedUrl();
  }

  void _applySeedUrl() {
    final raw = widget.product.imageUrl?.trim();
    _url = raw != null && raw.isNotEmpty ? resolveShopImageUrl(raw) : null;
  }

  Future<void> _loadPxThumbFirst() async {
    if (!_preferPxThumb || !mounted) return;
    setState(() => _loadingPx = true);
    final u = await fetchPxSearchThumbnail(
      apiBase: _thumbApiBase,
      keyword: widget.product.pxMartImageSearchKeyword,
      pxProductId: widget.product.productId ?? ShopProduct.parsePxProductId(widget.product.sourceUrl),
    );
    if (!mounted) return;
    setState(() {
      _loadingPx = false;
      if (u != null && u.isNotEmpty) {
        _url = resolveShopImageUrl(u);
      } else {
        _url = null;
      }
    });
  }

  Future<void> _loadPxThumbAfterSeedFailed() async {
    if (_thumbApiBase.isEmpty || _pxFetchStarted) return;
    _pxFetchStarted = true;
    if (!mounted) return;
    setState(() {
      _loadingPx = true;
      _url = null;
    });
    final u = await fetchPxSearchThumbnail(
      apiBase: _thumbApiBase,
      keyword: widget.product.pxMartImageSearchKeyword,
      pxProductId: widget.product.productId ?? ShopProduct.parsePxProductId(widget.product.sourceUrl),
    );
    if (!mounted) return;
    setState(() {
      _loadingPx = false;
      if (u != null && u.isNotEmpty) {
        _url = resolveShopImageUrl(u);
      }
    });
  }

  void _onNetworkImageError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_preferPxThumb) {
        setState(() => _url = null);
        return;
      }
      _loadPxThumbAfterSeedFailed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    Widget placeholder({IconData icon = Icons.shopping_bag_outlined}) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _photoBg,
          borderRadius: borderRadius,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Center(child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline)),
      );
    }

    if (_loadingPx && (_url == null || _url!.isEmpty)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: _photoBg,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    if (_url == null || _url!.isEmpty) {
      return placeholder();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: Colors.white,
        child: Image.network(
          _url!,
          key: ValueKey<String>(_url!),
          fit: BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
          webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return ColoredBox(
              color: _photoBg,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            _onNetworkImageError();
            return placeholder(icon: Icons.image_not_supported_outlined);
          },
        ),
      ),
    );
  }
}
