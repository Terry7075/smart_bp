import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_bp/features/auth/auth_provider.dart';
import 'package:smart_bp/features/auth/role_guard.dart';
import 'package:smart_bp/features/family/data/family_links_repository.dart';
import 'package:smart_bp/features/family/presentation/family_providers.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/shop/presentation/widgets/order_delivery_timeline.dart';

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
      await ref.read(familyLinksRepositoryProvider).requestBind(
            familyUserId: uid,
            elderUserId: elderId,
            relation: _relationCtrl.text.trim(),
          );
      ref.invalidate(familyLinksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已送出綁定請求，待長輩在 App 內同意後即可查看代購進度')),
      );
      _elderIdCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ArgumentError ? (e.message?.toString() ?? '$e') : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('綁定失敗：$msg')),
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
                    '家屬為獨立帳號（profiles.role = family），輸入長輩 UUID 送出綁定請求後，'
                    '需由長輩在自己的 App 內按「同意」才會生效，之後即可查看代購進度。',
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

// ─────────────────────────────────────────────────────────────
// 家屬長輩綁定卡片：訂單清單 + inline compact 時間軸
// ─────────────────────────────────────────────────────────────

class _ElderLinkCard extends ConsumerStatefulWidget {
  const _ElderLinkCard({required this.link});

  final FamilyElderLink link;

  @override
  ConsumerState<_ElderLinkCard> createState() => _ElderLinkCardState();
}

class _ElderLinkCardState extends ConsumerState<_ElderLinkCard> {
  static const Color _purple = Color(0xFF6A1B9A);
  bool _showAllOrders = false;

  @override
  Widget build(BuildContext context) {
    final isPending = widget.link.status != 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 長輩姓名與稱謂
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _purple.withValues(alpha: 0.12),
                  child: const Icon(Icons.elderly, color: _purple, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.link.elderName ?? '長輩',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text('我的${widget.link.relation}', style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                if (!isPending)
                  IconButton(
                    tooltip: '重新整理',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(
                        familyElderOrdersProvider(widget.link.elderUserId)),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '等待長輩在 App 內同意綁定中，同意後才能查看代購進度。',
                        style: TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildOrders(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(BuildContext context) {
    final orders = ref.watch(familyElderOrdersProvider(widget.link.elderUserId));
    return orders.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('訂單讀取失敗：$e', style: const TextStyle(fontSize: 16)),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('尚無代購需求單', style: TextStyle(fontSize: 17)),
                  );
                }
                final visible = _showAllOrders ? list : list.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final order in visible) ...[
                      _FamilyOrderCard(order: order),
                      const SizedBox(height: 8),
                    ],
                    if (list.length > 5)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showAllOrders = !_showAllOrders),
                          icon: Icon(_showAllOrders ? Icons.expand_less : Icons.list_alt),
                          label: Text(
                            _showAllOrders ? '收合列表' : '查看全部 ${list.length} 筆',
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
  }
}

// ─────────────────────────────────────────────────────────────
// 家屬訂單卡片：狀態 chip + 緊急徽章 + 品項摘要 + inline compact 時間軸
// ─────────────────────────────────────────────────────────────

class _FamilyOrderCard extends StatefulWidget {
  const _FamilyOrderCard({required this.order});

  final ShopOrderListRow order;

  @override
  State<_FamilyOrderCard> createState() => _FamilyOrderCardState();
}

class _FamilyOrderCardState extends State<_FamilyOrderCard> {
  bool _showTimeline = false;

  static String _formatDate(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.month}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => const Color(0xFF1565C0),
      'processing' => const Color(0xFFE65100),
      'completed' => const Color(0xFF2E7D32),
      'cancelled' => Colors.grey,
      _ => Colors.grey,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'pending' => Icons.hourglass_top_outlined,
      'processing' => Icons.local_shipping_outlined,
      'completed' => Icons.check_circle_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final color = _statusColor(order.status);
    final itemSummary = order.items.isEmpty
        ? '（無品項）'
        : order.items.take(3).map((it) {
            final unit = it.unitLabel != null && it.unitLabel!.isNotEmpty
                ? it.unitLabel!
                : '件';
            return '${it.productName} ×${it.quantity}$unit';
          }).join('、') + (order.items.length > 3 ? '…' : '');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: order.isUrgent ? const Color(0xFFE65100) : color.withValues(alpha: 0.3),
          width: order.isUrgent ? 2 : 1,
        ),
        color: order.isUrgent ? const Color(0xFFFFF8F5) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 標頭列：狀態 chip + 緊急 badge + 日期
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                // 狀態 chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(order.status), size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        ShopOrderStatus.orderStatusLabel(order.status),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                // 緊急 badge
                if (order.isUrgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emergency, size: 13, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          '緊急',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDate(order.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // ── 品項摘要
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              itemSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
          // ── 按鈕列
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                // 展開時間軸
                TextButton.icon(
                  onPressed: () => setState(() => _showTimeline = !_showTimeline),
                  icon: Icon(
                    _showTimeline ? Icons.expand_less : Icons.timeline,
                    size: 18,
                  ),
                  label: Text(
                    _showTimeline ? '收起進度' : '查看進度',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                // 前往完整詳情頁
                TextButton.icon(
                  onPressed: () => context.push('/shop/orders/${order.id}'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('完整詳情', style: TextStyle(fontSize: 14)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          // ── inline compact 時間軸（展開時顯示）
          if (_showTimeline)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 8),
                  const SizedBox(height: 8),
                  OrderDeliveryTimeline(order: order, compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
