import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/driver_standing_ride_offer.dart';

enum _OfferFilter { pending, approved, rejected, booked, cancelled, all }

class AdminStandingRidesPage extends ConsumerStatefulWidget {
  const AdminStandingRidesPage({super.key});

  @override
  ConsumerState<AdminStandingRidesPage> createState() =>
      _AdminStandingRidesPageState();
}

class _AdminStandingRidesPageState
    extends ConsumerState<AdminStandingRidesPage> {
  var _filter = _OfferFilter.pending;

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(adminDriverStandingRideOffersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('長期接送方案審核')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminDriverStandingRideOffersProvider);
            ref.invalidate(pendingDriverStandingRideOffersProvider);
          },
          child: ListView(
            children: [
              Text('司機可服務方案', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_OfferFilter>(
                  segments: const [
                    ButtonSegment(
                        value: _OfferFilter.pending, label: Text('待審')),
                    ButtonSegment(
                        value: _OfferFilter.approved, label: Text('可選')),
                    ButtonSegment(
                        value: _OfferFilter.booked, label: Text('已配對')),
                    ButtonSegment(
                        value: _OfferFilter.rejected, label: Text('退回')),
                    ButtonSegment(
                        value: _OfferFilter.cancelled, label: Text('取消')),
                    ButtonSegment(value: _OfferFilter.all, label: Text('全部')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              const SizedBox(height: 12),
              offers.when(
                data: (items) {
                  final filtered = _filterOffers(items);
                  if (filtered.isEmpty) {
                    return const _EmptyPanel('沒有符合條件的司機長期接送方案');
                  }
                  return Column(
                    children: filtered
                        .map((offer) => _AdminOfferCard(offer: offer))
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _EmptyPanel('讀取司機方案失敗：$error'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DriverStandingRideOffer> _filterOffers(
      List<DriverStandingRideOffer> items) {
    return switch (_filter) {
      _OfferFilter.pending => items
          .where((item) => item.status == DriverStandingRideOfferStatus.pending)
          .toList(),
      _OfferFilter.approved => items
          .where(
              (item) => item.status == DriverStandingRideOfferStatus.approved)
          .toList(),
      _OfferFilter.rejected => items
          .where(
              (item) => item.status == DriverStandingRideOfferStatus.rejected)
          .toList(),
      _OfferFilter.booked => items
          .where((item) => item.status == DriverStandingRideOfferStatus.booked)
          .toList(),
      _OfferFilter.cancelled => items
          .where(
              (item) => item.status == DriverStandingRideOfferStatus.cancelled)
          .toList(),
      _OfferFilter.all => items,
    };
  }
}

class _AdminOfferCard extends ConsumerStatefulWidget {
  const _AdminOfferCard({required this.offer});

  final DriverStandingRideOffer offer;

  @override
  ConsumerState<_AdminOfferCard> createState() => _AdminOfferCardState();
}

class _AdminOfferCardState extends ConsumerState<_AdminOfferCard> {
  String? _busyAction;

  Future<void> _run(String action, Future<void> Function() operation) async {
    setState(() => _busyAction = action);
    try {
      await operation();
      ref.invalidate(adminDriverStandingRideOffersProvider);
      ref.invalidate(pendingDriverStandingRideOffersProvider);
      ref.invalidate(adminDashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_successMessage(action))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退回方案'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '退回原因'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退回'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      'reject',
      () => ref
          .read(standingRideServiceProvider)
          .rejectDriverStandingRideOffer(widget.offer.id, controller.text),
    );
  }

  String _successMessage(String action) => switch (action) {
        'approve' => '已核准方案',
        'reject' => '已退回方案',
        'cancel' => '已取消方案',
        _ => '已完成操作',
      };

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final isBusy = _busyAction != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.displayDestination,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(offer.status.label)),
              ],
            ),
            Text('司機：${offer.driverId.substring(0, 8)}'),
            Text('上車：${offer.pickupLocation}'),
            Text('星期：${offer.serviceWeekdaysLabel}'),
            Text('時間：${offer.rideTime.substring(0, 5)}'),
            Text('可載：${offer.passengerCount} 人'),
            Text('開始：${DateFormat('yyyy/MM/dd').format(offer.startDate)}'),
            if (offer.endDate != null)
              Text('結束：${DateFormat('yyyy/MM/dd').format(offer.endDate!)}'),
            if (offer.needReturn && offer.returnTime != null)
              Text('回程：${offer.returnTime!.substring(0, 5)}'),
            if (offer.note != null) Text('備註：${offer.note}'),
            if (offer.rejectionReason != null)
              Text('退回原因：${offer.rejectionReason}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (offer.status == DriverStandingRideOfferStatus.pending) ...[
                  FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _run(
                              'approve',
                              () => ref
                                  .read(standingRideServiceProvider)
                                  .approveDriverStandingRideOffer(offer.id),
                            ),
                    icon: const Icon(Icons.check),
                    label: Text(_busyAction == 'approve' ? '核准中...' : '核准'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : _reject,
                    icon: const Icon(Icons.close),
                    label: Text(_busyAction == 'reject' ? '退回中...' : '退回'),
                  ),
                ],
                if (offer.status == DriverStandingRideOfferStatus.approved)
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _run(
                              'cancel',
                              () => ref
                                  .read(standingRideServiceProvider)
                                  .cancelDriverStandingRideOffer(offer.id),
                            ),
                    icon: const Icon(Icons.cancel),
                    label: Text(_busyAction == 'cancel' ? '取消中...' : '取消'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(message)),
    );
  }
}
