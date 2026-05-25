import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/ride_match.dart';
import '../../models/ride_status.dart';

enum _DriverTaskFilter { today, unfinished, completed }

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  var _filter = _DriverTaskFilter.unfinished;

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverApplicationProvider).value;
    final matches = driver == null
        ? const AsyncData<List<RideMatch>>(<RideMatch>[])
        : ref.watch(driverMatchesProvider(driver.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('司機任務'),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications),
          ),
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: driver == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_DriverTaskFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _DriverTaskFilter.unfinished,
                        label: Text('未完成'),
                        icon: Icon(Icons.pending_actions),
                      ),
                      ButtonSegment(
                        value: _DriverTaskFilter.today,
                        label: Text('今日'),
                        icon: Icon(Icons.today),
                      ),
                      ButtonSegment(
                        value: _DriverTaskFilter.completed,
                        label: Text('已完成'),
                        icon: Icon(Icons.done),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (value) => setState(() => _filter = value.first),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: matches.when(
                      data: (items) {
                        final filtered = _filterMatches(items);
                        if (filtered.isEmpty) {
                          return const Center(child: Text('目前沒有符合條件的任務'));
                        }
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final match = filtered[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.local_taxi),
                                title: Text(match.status.label),
                                subtitle: Text('行程 ${match.rideRequestId.substring(0, 8)}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                  '/driver/active/${match.id}/${match.rideRequestId}',
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('讀取任務失敗：$error')),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.push('/driver/available'),
                    icon: const Icon(Icons.search),
                    label: const Text('查看可接任務'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/driver/standing/create'),
                    icon: const Icon(Icons.event_available),
                    label: const Text('刊登長期接送'),
                  ),
                ],
              ),
      ),
    );
  }

  List<RideMatch> _filterMatches(List<RideMatch> items) {
    return switch (_filter) {
      _DriverTaskFilter.unfinished => items
          .where((item) =>
              item.status != RideStatus.completed && item.status != RideStatus.cancelled)
          .toList(),
      _DriverTaskFilter.completed =>
        items.where((item) => item.status == RideStatus.completed).toList(),
      _DriverTaskFilter.today => items,
    };
  }
}
