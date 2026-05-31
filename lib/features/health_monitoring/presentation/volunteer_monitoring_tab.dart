import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../health_monitoring_models.dart';
import '../health_monitoring_provider.dart';
import 'elder_health_detail_sheet.dart';

/// 志工的「長者監測」Tab：列出所有長輩的最新指標摘要。
class VolunteerMonitoringTab extends ConsumerWidget {
  const VolunteerMonitoringTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(allElderHealthSummariesProvider);

    return summariesAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('目前系統中尚無長輩帳號。'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(allElderHealthSummariesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            itemBuilder: (_, i) => _ElderSummaryCard(summary: list[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('載入失敗：$e'),
            TextButton(
              onPressed: () => ref.invalidate(allElderHealthSummariesProvider),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElderSummaryCard extends StatelessWidget {
  const _ElderSummaryCard({required this.summary});

  final ElderHealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conn = summary.connection;
    final lastSync = conn?.lastSyncAt;

    final syncLabel = lastSync != null
        ? '最後同步 ${_fmtTime(lastSync)}'
        : (conn == null ? '尚未綁定' : '從未同步');

    final syncColor = lastSync != null &&
            DateTime.now().difference(lastSync).inHours < 24
        ? Colors.green
        : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ElderHealthDetailSheet.show(context, summary),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      summary.elderName.isNotEmpty
                          ? summary.elderName[0]
                          : '?',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.elderName,
                            style: theme.textTheme.titleSmall),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: syncColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(syncLabel,
                                style: TextStyle(
                                    fontSize: 11, color: syncColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (summary.hasData) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: summary.latestByType.entries
                      .map((e) => _MetricChip(type: e.key, point: e.value))
                      .toList(),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('暫無健康資料',
                      style: TextStyle(
                          color: theme.colorScheme.outline, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MM/dd HH:mm').format(dt);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.type, required this.point});

  final String type;
  final HealthMetricPoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${HealthMetricType.label(type)} ${point.value.toStringAsFixed(0)} ${HealthMetricType.unitFor(type)}',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
