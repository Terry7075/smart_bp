import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminDashboardStatsProvider);

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
        child: stats.when(
          data: (item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(label: '待媒合接送', value: item.pendingRideCount),
                    _MetricCard(label: '今日行程', value: item.todayRideCount),
                    _MetricCard(label: '今日已媒合', value: item.todayMatchedCount),
                    _MetricCard(label: '進行中接送', value: item.inProgressCount),
                    _MetricCard(label: '待審核司機', value: item.pendingDriverCount),
                    _MetricCard(
                        label: '待審長期接送', value: item.pendingStandingRideCount),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push('/admin/drivers'),
                  child: const Text('司機審核'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/admin/standing'),
                  child: const Text('長期接送審核'),
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
