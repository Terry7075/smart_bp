import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/ride_status.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingDrivers = ref.watch(pendingDriverApplicationsProvider);
    final rides = ref.watch(todayRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理員儀表板'),
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
        child: rides.when(
          data: (items) {
            final pendingCount = items.where((r) => r.status == RideStatus.pending).length;
            final matchedCount = items.where((r) => r.status == RideStatus.matched).length;
            final inProgressCount = items.where((r) =>
                r.status == RideStatus.pickedUp || r.status == RideStatus.onTheWay).length;
            final pendingDriverCount = pendingDrivers.value?.length ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: '今日待媒合', value: pendingCount),
                    _MetricCard(label: '今日已媒合', value: matchedCount),
                    _MetricCard(label: '進行中接送', value: inProgressCount),
                    _MetricCard(label: '待審核司機', value: pendingDriverCount),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push('/admin/drivers'),
                  child: const Text('司機審核'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/admin/match'),
                  child: const Text('接送媒合'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/admin/live'),
                  child: const Text('即時狀態監控'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('讀取失敗：$error')),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
