import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class AdminDriverApprovalPage extends ConsumerStatefulWidget {
  const AdminDriverApprovalPage({super.key});

  @override
  ConsumerState<AdminDriverApprovalPage> createState() =>
      _AdminDriverApprovalPageState();
}

class _AdminDriverApprovalPageState
    extends ConsumerState<AdminDriverApprovalPage> {
  String? _reviewingDriverId;

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(pendingDriverApplicationsProvider);

    Future<void> review(String driverId, String status) async {
      setState(() => _reviewingDriverId = driverId);
      try {
        await ref.read(driverServiceProvider).reviewApplication(
              driverId: driverId,
              approvalStatus: status,
            );
        ref.invalidate(pendingDriverApplicationsProvider);
        ref.invalidate(approvedDriversProvider);
        ref.invalidate(adminDashboardStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(status == 'approved' ? '已通過司機申請' : '已拒絕司機申請')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('審核失敗：$error')),
          );
        }
      } finally {
        if (mounted) setState(() => _reviewingDriverId = null);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('司機審核')),
      body: applications.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('目前沒有待審核司機'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final driver = items[index];
                  final reviewing = _reviewingDriverId == driver.id;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('電話：${driver.phone}'),
                          Text('地址：${driver.address}'),
                          Text('車牌：${driver.carPlate}'),
                          Text('車型：${driver.carModel ?? '未填'}'),
                          Text('可載人數：${driver.maxPassengers}'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _reviewingDriverId == null
                                      ? () => review(driver.id, 'approved')
                                      : null,
                                  child: Text(reviewing ? '處理中...' : '通過'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _reviewingDriverId == null
                                      ? () => review(driver.id, 'rejected')
                                      : null,
                                  child: Text(reviewing ? '處理中...' : '拒絕'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
