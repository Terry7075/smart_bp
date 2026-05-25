import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/driver_standing_ride_offer.dart';
import '../../models/standing_ride_request.dart';

class ElderStandingRidesPage extends ConsumerWidget {
  const ElderStandingRidesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(approvedDriverStandingRideOffersProvider);
    final myRequests = ref.watch(myStandingRideRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('長期接送')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(approvedDriverStandingRideOffersProvider);
          ref.invalidate(myStandingRideRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('可選擇方案', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            offers.when(
              data: (items) => items.isEmpty
                  ? const _EmptyText('目前沒有可選擇的長期接送方案')
                  : Column(
                      children: items
                          .map((offer) => _OfferCard(offer: offer))
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyText('讀取方案失敗：$error'),
            ),
            const SizedBox(height: 24),
            Text('我的長期接送', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            myRequests.when(
              data: (items) => items.isEmpty
                  ? const _EmptyText('尚未選擇長期接送')
                  : Column(
                      children: items
                          .map((request) =>
                              _StandingRideCard(request: request))
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyText('讀取紀錄失敗：$error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.offer});

  final DriverStandingRideOffer offer;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  var _selecting = false;

  Future<void> _select() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇長期接送'),
        content: Text('確認選擇「${widget.offer.displayDestination}」？選擇後會直接配對司機。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確認選擇'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _selecting = true);
    try {
      await ref
          .read(standingRideServiceProvider)
          .selectDriverStandingRideOffer(widget.offer.id);
      ref.invalidate(approvedDriverStandingRideOffersProvider);
      ref.invalidate(myStandingRideRequestsProvider);
      ref.invalidate(myRideRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已建立長期接送')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選擇失敗：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
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
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _selecting ? null : _select,
              icon: const Icon(Icons.check_circle),
              label: Text(_selecting ? '建立中...' : '選擇並配對'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingRideCard extends StatelessWidget {
  const _StandingRideCard({required this.request});

  final StandingRideRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(request.displayDestination),
        subtitle: Text(
          '${request.serviceWeekdaysLabel} ${request.rideTime.substring(0, 5)}',
        ),
        trailing: Chip(label: Text(request.status.label)),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text)),
    );
  }
}
