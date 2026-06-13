import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class DriverPendingApprovalPage extends ConsumerWidget {
  const DriverPendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(currentDriverApplicationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('司機審核狀態'),
        actions: [
          IconButton(
            onPressed: () => context.push('/transport/profile'),
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: application.when(
          data: (driver) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_top, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      driver?.isRejected == true ? '申請已被拒絕' : '等待管理員審核',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(driver?.isRejected == true
                        ? '請聯絡管理員確認資料後再處理。'
                        : '審核通過後，你就可以查看待接任務。'),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () {
                        ref.invalidate(currentDriverApplicationProvider);
                        ref.invalidate(currentProfileProvider);
                      },
                      child: const Text('重新整理審核狀態'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('讀取失敗：$error')),
        ),
      ),
    );
  }
}
