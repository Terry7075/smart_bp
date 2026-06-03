import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/ride_request.dart';

class DriverAvailableRequestsPage extends ConsumerStatefulWidget {
  const DriverAvailableRequestsPage({super.key});

  @override
  ConsumerState<DriverAvailableRequestsPage> createState() =>
      _DriverAvailableRequestsPageState();
}

class _DriverAvailableRequestsPageState
    extends ConsumerState<DriverAvailableRequestsPage> {
  String? _acceptingRideId;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(pendingRideRequestsProvider);
    final driverState = ref.watch(currentDriverApplicationProvider);
    final driver = driverState.value;

    return Scaffold(
      appBar: AppBar(title: const Text('待接任務')),
      body: driverState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : driverState.hasError
              ? Center(child: Text('讀取司機資料失敗：${driverState.error}'))
              : requests.when(
                  data: (items) {
                    final eligibleItems =
                        _eligibleItems(items, driver?.maxPassengers);
                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(pendingRideRequestsProvider),
                      child: eligibleItems.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 180),
                              Center(child: Text('目前沒有待接任務'))
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: eligibleItems.length,
                              itemBuilder: (context, index) {
                                final ride = eligibleItems[index];
                                final accepting = _acceptingRideId == ride.id;
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(ride.displayDestination,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        Text('出發地：${ride.pickupLocation}'),
                                        Text(
                                            '日期：${DateFormat('yyyy/MM/dd').format(ride.rideDate)}'),
                                        Text(
                                            '時間：${ride.rideTime.substring(0, 5)}'),
                                        Text('人數：${ride.passengerCount}'),
                                        if (ride.note != null)
                                          Text('備註：${ride.note}'),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: _acceptingRideId == null
                                              ? () async {
                                                  setState(() =>
                                                      _acceptingRideId =
                                                          ride.id);
                                                  try {
                                                    await ref
                                                        .read(
                                                            rideServiceProvider)
                                                        .acceptRide(ride.id);
                                                    ref.invalidate(
                                                        pendingRideRequestsProvider);
                                                    ref.invalidate(
                                                        adminRideRequestsProvider);
                                                    ref.invalidate(
                                                        adminDashboardStatsProvider);
                                                    if (driver != null) {
                                                      ref.invalidate(
                                                          driverMatchesProvider(
                                                              driver.id));
                                                    }
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content:
                                                                Text('已成功接案')),
                                                      );
                                                    }
                                                  } catch (error) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                '接案失敗：$error')),
                                                      );
                                                    }
                                                  } finally {
                                                    if (mounted) {
                                                      setState(() =>
                                                          _acceptingRideId =
                                                              null);
                                                    }
                                                  }
                                                }
                                              : null,
                                          child: Text(
                                              accepting ? '接案中...' : '我要接送'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('讀取失敗：$error')),
                ),
    );
  }

  List<RideRequest> _eligibleItems(
      List<RideRequest> items, int? maxPassengers) {
    if (maxPassengers == null) return items;
    return items.where((ride) => ride.passengerCount <= maxPassengers).toList();
  }
}
