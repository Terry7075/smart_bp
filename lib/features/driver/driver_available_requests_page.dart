import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

class DriverAvailableRequestsPage extends ConsumerWidget {
  const DriverAvailableRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingRideRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('待接任務')),
      body: requests.when(
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingRideRequestsProvider),
          child: items.isEmpty
              ? ListView(children: const [SizedBox(height: 180), Center(child: Text('目前沒有待接任務'))])
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final ride = items[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ride.displayDestination,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('出發地：${ride.pickupLocation}'),
                            Text('日期：${DateFormat('yyyy/MM/dd').format(ride.rideDate)}'),
                            Text('時間：${ride.rideTime.substring(0, 5)}'),
                            Text('人數：${ride.passengerCount}'),
                            if (ride.note != null) Text('備註：${ride.note}'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await ref.read(rideServiceProvider).acceptRide(ride.id);
                                  ref.invalidate(pendingRideRequestsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已成功接案')),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('接案失敗：$error')),
                                    );
                                  }
                                }
                              },
                              child: const Text('我要接送'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀取失敗：$error')),
      ),
    );
  }
}
