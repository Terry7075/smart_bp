import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/shop/domain/fulfillment_status.dart';
import 'package:smart_bp/features/shop/presentation/shop_collaboration_providers.dart';

/// 志工：已購買 / 已發放 / 替代。
class VolunteerItemFulfillmentSheet extends ConsumerStatefulWidget {
  const VolunteerItemFulfillmentSheet({
    super.key,
    required this.itemId,
    required this.productLabel,
    required this.elderLabel,
  });

  final String itemId;
  final String productLabel;
  final String elderLabel;

  @override
  ConsumerState<VolunteerItemFulfillmentSheet> createState() =>
      _VolunteerItemFulfillmentSheetState();
}

class _VolunteerItemFulfillmentSheetState
    extends ConsumerState<VolunteerItemFulfillmentSheet> {
  bool _busy = false;
  final _priceCtrl = TextEditingController();

  Future<void> _set(ItemFulfillmentStatus status) async {
    setState(() => _busy = true);
    try {
      final price = double.tryParse(_priceCtrl.text.trim());
      await ref.read(fulfillmentRepositoryProvider).updateStatus(
            itemId: widget.itemId,
            status: status,
            actualUnitPrice: price,
            note: status == ItemFulfillmentStatus.substituted
                ? '志工標記替代'
                : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.productLabel,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text('長輩：${widget.elderLabel}', style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 16),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '實際購買單價（選填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _ActionBtn(
            label: '標記已購買',
            color: Colors.orange.shade800,
            busy: _busy,
            onPressed: () => _set(ItemFulfillmentStatus.purchased),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: '標記已發放',
            color: Colors.green.shade800,
            busy: _busy,
            onPressed: () => _set(ItemFulfillmentStatus.delivered),
          ),
          const SizedBox(height: 8),
          _ActionBtn(
            label: '缺貨・替代商品',
            color: Colors.deepPurple,
            busy: _busy,
            onPressed: () => _set(ItemFulfillmentStatus.substituted),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size.fromHeight(48)),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}
