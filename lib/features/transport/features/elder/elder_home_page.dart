import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/ride_status.dart';

class ElderHomePage extends ConsumerWidget {
  const ElderHomePage({super.key});

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/home?tab=0');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(myRideRequestsProvider);
    final application = ref.watch(currentDriverApplicationProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            iconSize: 30,
            onPressed: () => _goBack(context),
          ),
          title: const Text('長者首頁'),
          actions: [
            IconButton(
              onPressed: () => context.push('/transport/notifications'),
              icon: const Icon(Icons.notifications),
            ),
            IconButton(
              onPressed: () => context.push('/transport/profile'),
              icon: const Icon(Icons.account_circle),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: rides.when(
            data: (items) {
              final active = items
                  .where(
                    (ride) =>
                        ride.status != RideStatus.completed &&
                        ride.status != RideStatus.cancelled,
                  )
                  .toList();
              final current = active.isEmpty ? null : active.first;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '目前接送狀態',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: current == null
                            ? const Text('目前沒有進行中的接送')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    current.status.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Text('目的地：${current.displayDestination}'),
                                  Text(
                                    '日期：${DateFormat('yyyy/MM/dd').format(current.rideDate)}',
                                  ),
                                  Text(
                                    '時間：${current.rideTime.substring(0, 5)}',
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () => context.push(
                                      '/transport/elder/ride/${current.id}',
                                    ),
                                    child: const Text('查看詳情'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/transport/elder/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('新增接送'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/transport/elder/standing'),
                      icon: const Icon(Icons.event_repeat),
                      label: const Text('長期接送申請'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push('/transport/elder/history'),
                      child: const Text('我的接送紀錄'),
                    ),
                    const SizedBox(height: 12),
                    if (application == null)
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/transport/driver/apply'),
                        child: const Text('申請成為司機'),
                      )
                    else if (application.isPending)
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/transport/driver/pending'),
                        child: const Text('查看司機審核狀態'),
                      ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('讀取失敗：$error')),
          ),
        ),
      ),
    );
  }
}
