import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/shop/data/image_proxy.dart';
import 'package:smart_bp/features/shop/data/px_search_thumb_client.dart';
import 'package:smart_bp/features/shop/domain/shop_product.dart';
import 'package:smart_bp/features/shop/presentation/shop_orders_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_products_provider.dart';
import 'package:smart_bp/features/shop/presentation/shop_volunteer_orders_provider.dart';
import 'package:smart_bp/shared/widgets/mindu_loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 全聯全電商（pxbox）首頁；`openExternalBrowser=1` 利於從 App／WebView 改以外部瀏覽器開啟。
const String kPxMartBoxHomeUrl =
    'https://pxbox.es.pxmart.com.tw/?openExternalBrowser=1&utm_source=google&utm_medium=md_cpc&utm_campaign=brand_main_conv_2605&utm_content=260508-260528_normal&gad_source=1';

/// 與「全聯搜尋」按鈕相同：導向 pxbox 搜尋結果頁，關鍵字為 [ShopProduct.pxMartSearchKeyword]。
Uri buildPxMartSearchResultUri(ShopProduct product) {
  final kw = product.pxMartSearchKeyword.trim();
  if (kw.isEmpty) {
    return Uri.https('pxbox.es.pxmart.com.tw', '/', {'openExternalBrowser': '1'});
  }
  return Uri.https('pxbox.es.pxmart.com.tw', '/search/result', {
    'keyword': kw,
    'openExternalBrowser': '1',
  });
}

Future<void> _openPxMartBoxHome(BuildContext context) async {
  final uri = Uri.parse(kPxMartBoxHomeUrl);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯網頁，請稍後再試')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開啟失敗：$e')),
      );
    }
  }
}

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
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.receipt_long, size: 24),
            label: const Text(
              '我的需求',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => context.push('/shop/orders'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.store_mall_directory_outlined, size: 26),
            label: const Text(
              '全聯首頁',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _openPxMartBoxHome(context),
          ),
        ],
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

class _ShopOrderView extends ConsumerStatefulWidget {
  const _ShopOrderView({
    required this.products,
    required this.colorScheme,
    required this.accent,
  });

  final List<ShopProduct> products;
  final ColorScheme colorScheme;
  final Color accent;

  @override
  ConsumerState<_ShopOrderView> createState() => _ShopOrderViewState();
}

class _ShopOrderViewState extends ConsumerState<_ShopOrderView> {
  late final Map<String, int> _quantities;
  final _searchController = TextEditingController();
  final _manualBrandController = TextEditingController();
  final _manualTitleController = TextEditingController();
  final _manualSpecController = TextEditingController();
  final _manualPxKeywordController = TextEditingController();
  final _manualLinkController = TextEditingController();
  final _manualPriceController = TextEditingController();
  final List<ShopProduct> _manualProducts = [];
  String _search = '';
  String _selectedCategory = '全部';
  static const int _pageSize = 48;
  int _pageIndex = 0;
  bool _showAll = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _quantities = {for (final p in widget.products) p.id: 0};
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualBrandController.dispose();
    _manualTitleController.dispose();
    _manualSpecController.dispose();
    _manualPxKeywordController.dispose();
    _manualLinkController.dispose();
    _manualPriceController.dispose();
    super.dispose();
  }

  List<ShopProduct> get _allProductsForOrder => [...widget.products, ..._manualProducts];

  bool _isManualProductId(String id) => id.startsWith('manual_');

  void _changeQty(String id, int delta) {
    final current = _quantities[id] ?? 0;
    final next = (current + delta).clamp(0, 999);
    if (_isManualProductId(id) && next <= 0) {
      setState(() {
        _manualProducts.removeWhere((p) => p.id == id);
        _quantities.remove(id);
      });
      return;
    }
    setState(() => _quantities[id] = next);
  }

  int get _totalCount => _quantities.values.fold(0, (sum, qty) => sum + qty);

  double get _totalAmount {
    var total = 0.0;
    for (final p in _allProductsForOrder) {
      final qty = _quantities[p.id] ?? 0;
      if (p.unitPrice != null && qty > 0) total += p.unitPrice! * qty;
    }
    return total;
  }

  void _clearManualFields() {
    _manualBrandController.clear();
    _manualTitleController.clear();
    _manualSpecController.clear();
    _manualPxKeywordController.clear();
    _manualLinkController.clear();
    _manualPriceController.clear();
  }

  /// 依表單組一筆手填商品；[id] 須為唯一（例如 `manual_…`）。
  ShopProduct? _buildManualShopProductWithId(String id) {
    final title = _manualTitleController.text.trim();
    if (title.isEmpty) return null;
    final brand = _manualBrandController.text.trim();
    final specStr = _manualSpecController.text.trim();
    final pxKw = _manualPxKeywordController.text.trim();

    final nameBuf = StringBuffer('(手填) ');
    if (brand.isNotEmpty) {
      nameBuf.write('【$brand】');
    }
    nameBuf.write(title);

    final linkRaw = _manualLinkController.text.trim();
    String? sourceUrl;
    if (linkRaw.isNotEmpty) {
      final m = RegExp(r'https?://\S+').firstMatch(linkRaw);
      sourceUrl = m?.group(0) ?? linkRaw;
    }
    final priceRaw = _manualPriceController.text.trim();
    double? unitPrice;
    if (priceRaw.isNotEmpty) {
      unitPrice = double.tryParse(priceRaw.replaceAll(',', ''));
    }
    return ShopProduct(
      id: id,
      name: nameBuf.toString(),
      spec: specStr.isEmpty ? null : specStr,
      category: '手填／其他',
      unitPrice: unitPrice,
      unitLabel: '參考',
      sourceUrl: sourceUrl,
      productId: ShopProduct.parsePxProductId(sourceUrl),
      promoText: '網站目錄未列；實際品項與價格以全聯為準。',
      notes: 'manual_line',
      fetchedAt: DateTime.now().toIso8601String(),
      confidence: 'manual',
      pxSearchKeywordOverride: pxKw.isEmpty ? null : pxKw,
    );
  }

  Future<void> _launchPxMartSearchForProduct(ShopProduct product) async {
    final uri = buildPxMartSearchResultUri(product);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯搜尋頁，請稍後再試')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已開啟全聯搜尋：${product.pxMartSearchKeyword}')),
    );
  }

  /// 依目前表單開全聯搜尋；[addToCart] 為 true 時一併加入手填清單並數量 +1。
  Future<void> _manualFormOpenPxSearch({required bool addToCart}) async {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    final p = _buildManualShopProductWithId(id);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先填寫品名／品相')));
      return;
    }
    final uri = buildPxMartSearchResultUri(p);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟全聯搜尋頁，請稍後再試')),
      );
      return;
    }
    if (addToCart) {
      setState(() {
        _manualProducts.add(p);
        _quantities[p.id] = (_quantities[p.id] ?? 0) + 1;
        _clearManualFields();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入 1 件並開啟全聯搜尋：${p.pxMartSearchKeyword}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已開啟全聯搜尋：${p.pxMartSearchKeyword}')),
      );
    }
  }

  void _addManualProductLine() {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    final product = _buildManualShopProductWithId(id);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫品名／品相')));
      return;
    }
    setState(() {
      _manualProducts.add(product);
      _quantities[product.id] = 1;
      _clearManualFields();
    });
  }

  void _removeManualProductLine(String id) {
    if (!_isManualProductId(id)) return;
    setState(() {
      _manualProducts.removeWhere((p) => p.id == id);
      _quantities.remove(id);
    });
  }

  Future<void> _submitOrder() async {
    if (_totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先選擇至少一項商品數量')));
      return;
    }

    final session = ref.read(authProvider);
    final user = session?.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入再送出需求')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(shopOrdersRepositoryProvider);
      final orderId = await repo.createOrder(
        userId: user.id,
        products: _allProductsForOrder,
        quantitiesByProductId: _quantities,
      );
      if (!mounted) return;
      ref.invalidate(shopVolunteerOrdersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已送出需求單（編號前 8 碼：${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}…）\n志工可在「物資／柑仔店需求」查看'),
          action: SnackBarAction(
            label: '查看我的需求',
            onPressed: () {
              if (mounted) context.push('/shop/orders');
            },
          ),
        ),
      );
      setState(() {
        for (final k in _quantities.keys.toList()) {
          if (_isManualProductId(k)) {
            _quantities.remove(k);
          } else {
            _quantities[k] = 0;
          }
        }
        _manualProducts.clear();
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗：${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final clampedPageIndex = _pageIndex.clamp(0, totalPages - 1);
    if (clampedPageIndex != _pageIndex) {
      // 避免搜尋／分類切換後頁碼超出範圍
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pageIndex = clampedPageIndex);
      });
    }
    final visible = _showAll
        ? filtered
        : filtered.skip(clampedPageIndex * _pageSize).take(_pageSize).toList();

    return MinduLoadingOverlay(
      isLoading: _submitting,
      message: '送出需求中，請稍候...',
      child: Column(
        children: [
          Expanded(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                color: widget.colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: widget.colorScheme.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo：商品與參考價來自目錄；實際以全聯門市／官網為準。自訂手填區可收起；「全聯搜尋」會用關鍵字開 pxbox 搜尋頁，並可一併加入**本站需求清單**（非全聯官網購物車）。送出後志工可於「物資／柑仔店代購」查看。',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: widget.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: widget.colorScheme.secondaryContainer.withValues(alpha: 0.45),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                        shape: const RoundedRectangleBorder(side: BorderSide.none),
                        iconColor: widget.colorScheme.onSecondaryContainer,
                        collapsedIconColor: widget.colorScheme.onSecondaryContainer,
                        leading: Icon(
                          Icons.edit_note,
                          color: widget.colorScheme.onSecondaryContainer,
                          size: 26,
                        ),
                        title: Text(
                          '自訂商品（手填）',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: widget.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        subtitle: Text(
                          _manualProducts.isEmpty
                              ? '全聯有賣、本站沒列時，點開填寫'
                              : '已加入 ${_manualProducts.length} 筆（可收起）',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: widget.colorScheme.onSecondaryContainer.withValues(alpha: 0.88),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '品名必填；品牌、規格、全聯搜尋關鍵字可選。有填「全聯搜尋關鍵字」時，搜尋頁只帶該字串。按「僅開全聯搜尋」不會加入下方清單；「加入並開全聯搜尋」會加入我們的需求數量並開搜尋頁。',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    color: widget.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _manualBrandController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: '品牌（選填）',
                                    hintText: '例：義美',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualTitleController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: '品名／品相（必填）',
                                    hintText: '例：小泡芙 巧克力 57g',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualSpecController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: '規格補充（選填）',
                                    hintText: '例：6入組、有效日期需求等',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualPxKeywordController,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: '全聯搜尋關鍵字（選填）',
                                    hintText: '有填時，全聯搜尋頁只使用這一行',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualLinkController,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.url,
                                  decoration: InputDecoration(
                                    labelText: '全聯商品連結（選填）',
                                    hintText: 'https://pxbox.es.pxmart.com.tw/product/…',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _manualPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: '參考單價（選填）',
                                    hintText: '僅供估算，以全聯標價為準',
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _manualFormOpenPxSearch(addToCart: false),
                                      icon: const Icon(Icons.travel_explore_outlined, size: 20),
                                      label: const Text('僅開全聯搜尋'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => _manualFormOpenPxSearch(addToCart: true),
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text('加入並開全聯搜尋'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: _addManualProductLine,
                                      icon: const Icon(Icons.playlist_add_outlined),
                                      label: const Text('加入需求清單'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_manualProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(height: 1, color: widget.colorScheme.outlineVariant),
                            const SizedBox(height: 10),
                            Text(
                              '手填品項（${_manualProducts.length}）',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: widget.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final p in _manualProducts)
                              _ManualLineTile(
                                product: p,
                                quantity: _quantities[p.id] ?? 0,
                                colorScheme: widget.colorScheme,
                                onAdd: () => _changeQty(p.id, 1),
                                onRemove: () => _changeQty(p.id, -1),
                                onDeleteLine: () => _removeManualProductLine(p.id),
                                onOpenPxSearch: () => _launchPxMartSearchForProduct(p),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _search = value;
                  _pageIndex = 0;
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
                        _pageIndex = 0;
                      }),
                    ),
                    for (final category in categories)
                      _CategoryChip(
                        label: category,
                        selected: _selectedCategory == category,
                        onTap: () => setState(() {
                          _selectedCategory = category;
                          _pageIndex = 0;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '共 ${filtered.length} 件商品',
                      style: TextStyle(color: widget.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    _showAll
                        ? '全部顯示'
                        : '第 ${clampedPageIndex + 1} / $totalPages 頁（每頁 $_pageSize）',
                    style: TextStyle(color: widget.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _showAll = !_showAll;
                      _pageIndex = 0;
                    }),
                    child: Text(_showAll ? '改分頁' : '全部顯示'),
                  ),
                ],
              ),
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
                        key: ValueKey<String>(p.id),
                        product: p,
                        accent: widget.accent,
                        quantity: _quantities[p.id] ?? 0,
                        onAdd: () => _changeQty(p.id, 1),
                        onRemove: () => _changeQty(p.id, -1),
                        onAddWhenPxSearchOpened: () => _changeQty(p.id, 1),
                      );
                    },
                  );
                },
              ),
              if (!_showAll && filtered.length > _pageSize)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '上一頁',
                        onPressed: clampedPageIndex <= 0 ? null : () => setState(() => _pageIndex -= 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('第 ${clampedPageIndex + 1} / $totalPages 頁'),
                      IconButton(
                        tooltip: '下一頁',
                        onPressed: clampedPageIndex >= totalPages - 1 ? null : () => setState(() => _pageIndex += 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
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
                  FilledButton(
                    onPressed: _submitting ? null : _submitOrder,
                    child: const Text('送出需求'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualLineTile extends StatelessWidget {
  const _ManualLineTile({
    required this.product,
    required this.quantity,
    required this.colorScheme,
    required this.onAdd,
    required this.onRemove,
    required this.onDeleteLine,
    required this.onOpenPxSearch,
  });

  final ShopProduct product;
  final int quantity;
  final ColorScheme colorScheme;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDeleteLine;
  final VoidCallback onOpenPxSearch;

  @override
  Widget build(BuildContext context) {
    final url = product.sourceUrl;
    final priceText = product.unitPrice != null
        ? 'NT\$${product.unitPrice!.toStringAsFixed(0)}／件'
        : '單價未填（以全聯為準）';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.25)),
              if (product.spec != null && product.spec!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '規格：${product.spec}',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '全聯搜尋：${product.pxMartSearchKeyword}'
                '${product.pxSearchKeywordOverride != null && product.pxSearchKeywordOverride!.trim().isNotEmpty ? '（自訂關鍵字）' : '（由品名組合）'}',
                style: TextStyle(fontSize: 13, color: colorScheme.tertiary),
              ),
              const SizedBox(height: 4),
              Text(priceText, style: TextStyle(fontSize: 13, color: colorScheme.primary)),
              if (url != null && url.isNotEmpty) ...[
                const SizedBox(height: 6),
                SelectableText(
                  url,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  '無商品連結（志工可依品名在全聯搜尋）',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenPxSearch,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('全聯搜尋'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: quantity > 0 ? onRemove : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(40, 36), padding: EdgeInsets.zero),
                    child: const Text('－'),
                  ),
                  const SizedBox(width: 8),
                  Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(minimumSize: const Size(40, 36), padding: EdgeInsets.zero),
                    child: const Text('＋'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDeleteLine,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('移除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    super.key,
    required this.product,
    required this.accent,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.onAddWhenPxSearchOpened,
  });

  final ShopProduct product;
  final Color accent;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  /// 成功開啟全聯搜尋頁後，為**本站需求清單** +1（全聯網站購物車須在全聯頁面自行操作）。
  final VoidCallback? onAddWhenPxSearchOpened;
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
                          onPressed: () => _openProductUrl(
                            context,
                            product,
                            onAddWhenPxSearchOpened: onAddWhenPxSearchOpened,
                          ),
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

  static Future<void> _openProductUrl(
    BuildContext context,
    ShopProduct product, {
    VoidCallback? onAddWhenPxSearchOpened,
  }) async {
    final searchUri = buildPxMartSearchResultUri(product);
    final openedSearch = await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    if (openedSearch) {
      onAddWhenPxSearchOpened?.call();
      if (context.mounted && onAddWhenPxSearchOpened != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已開啟全聯搜尋「${product.pxMartSearchKeyword}」，並為需求清單 +1')),
        );
      }
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

  /// 預設 **false**（Demo 穩定）：先顯示種子目錄的圖，失敗才嘗試本機縮圖 API。
  /// 需要全聯搜尋縮圖時請加：`--dart-define=SHOP_PX_THUMB=true`
  static const bool _usePxThumbFirst =
      bool.fromEnvironment('SHOP_PX_THUMB', defaultValue: false);

  /// 圖搜全聯縮圖 API。
  ///
  /// - 可用 `--dart-define=PX_SEARCH_THUMB_API=...` 覆寫（Android 模擬器通常是 `http://10.0.2.2:8790`）
  /// - 未設定時預設用本機 node 服務（`npm run shop:px-search-thumb`）
  static String get _thumbApiBase {
    final fromEnv = const String.fromEnvironment('PX_SEARCH_THUMB_API').trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://127.0.0.1:8790';
  }

  bool get _preferPxThumb => _usePxThumbFirst;

  String? _url;
  bool _loadingPx = false;
  int _pxRetryCount = 0;
  /// 未開「僅全聯」模式時，是否已因種子破圖而改打全聯。
  bool _pxFetchStarted = false;

  void _schedulePxRetryIfNeeded() {
    if (!_preferPxThumb || !mounted) return;
    if (_loadingPx) return;
    if (_url != null && _url!.isNotEmpty) return;
    if (_pxRetryCount >= 3) return;
    _pxRetryCount += 1;
    final delayMs = 1200 * _pxRetryCount;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (_url != null && _url!.isNotEmpty) return;
      _loadPxThumbFirst();
    });
  }

  @override
  void initState() {
    super.initState();
    if (_preferPxThumb) {
      _pxFetchStarted = true;
      _loadPxThumbFirst();
    } else {
      _applySeedUrl();
    }
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
      cacheKey: widget.product.id,
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
    if (u == null || u.isEmpty) _schedulePxRetryIfNeeded();
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
      cacheKey: widget.product.id,
    );
    if (!mounted) return;
    setState(() {
      _loadingPx = false;
      if (u != null && u.isNotEmpty) {
        _url = resolveShopImageUrl(u);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ShopProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id == widget.product.id) return;
    _url = null;
    _loadingPx = false;
    _pxRetryCount = 0;
    _pxFetchStarted = false;
    if (_preferPxThumb) {
      _pxFetchStarted = true;
      _loadPxThumbFirst();
    } else {
      _applySeedUrl();
    }
  }

  void _onNetworkImageError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_preferPxThumb) {
        setState(() => _url = null);
        _schedulePxRetryIfNeeded();
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
