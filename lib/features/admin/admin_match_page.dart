import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/utils/price_calculator.dart';
import '../../models/driver.dart';
import '../../models/ride_request.dart';

class AdminMatchPage extends ConsumerWidget {
  const AdminMatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingRideRequestsProvider);
    final drivers = ref.watch(approvedDriversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('接送媒合')),
      body: requests.when(
        data: (rideItems) => drivers.when(
          data: (driverItems) => rideItems.isEmpty
              ? const Center(child: Text('目前沒有待媒合接送'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rideItems.length,
                  itemBuilder: (context, index) {
                    final ride = rideItems[index];
                    return _MatchCard(ride: ride, drivers: driverItems);
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('司機資料讀取失敗：$error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('接送資料讀取失敗：$error')),
      ),
    );
  }
}

class _MatchCard extends ConsumerStatefulWidget {
  const _MatchCard({required this.ride, required this.drivers});

  final RideRequest ride;
  final List<Driver> drivers;

  @override
  ConsumerState<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends ConsumerState<_MatchCard> {
  Driver? _selectedDriver;
  final _distanceController = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _match() async {
    final driver = _selectedDriver;
    final distance = num.tryParse(_distanceController.text);
    if (driver == null || distance == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(rideServiceProvider).manualMatchRide(
            rideRequestId: widget.ride.id,
            driverId: driver.id,
            distanceKm: distance,
          );
      ref.invalidate(pendingRideRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('媒合成功')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewDistance = num.tryParse(_distanceController.text);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ride.displayDestination, style: Theme.of(context).textTheme.titleMedium),
            Text('日期：${DateFormat('yyyy/MM/dd').format(widget.ride.rideDate)}'),
            Text('時間：${widget.ride.rideTime.substring(0, 5)}'),
            Text('人數：${widget.ride.passengerCount}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<Driver>(
              initialValue: _selectedDriver,
              decoration: const InputDecoration(labelText: '指定司機'),
              items: widget.drivers
                  .where((driver) => driver.maxPassengers >= widget.ride.passengerCount)
                  .map((driver) => DropdownMenuItem(
                        value: driver,
                        child: Text('${driver.name}（${driver.maxPassengers} 人）'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedDriver = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '距離（公里）'),
              onChanged: (_) => setState(() {}),
            ),
            if (previewDistance != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('預估費用：${calculatePrice(previewDistance)} 元'),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _match,
              child: Text(_saving ? '媒合中...' : '建立媒合'),
            ),
          ],
        ),
      ),
    );
  }
}
