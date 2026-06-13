import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/ride_status.dart';

class ElderRideHistoryPage extends ConsumerWidget {
  const ElderRideHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(myRideRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的接送紀錄')),
      body: rides.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('尚無接送紀錄'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final ride = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(ride.displayDestination),
                      subtitle: Text('${DateFormat('yyyy/MM/dd').format(ride.rideDate)} ${ride.rideTime.substring(0, 5)}'),
                      trailing: Text(ride.status.label),
                      onTap: () => context.push('/transport/elder/ride/${ride.id}'),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀取失敗：$error')),
      ),
    );
  }
}
