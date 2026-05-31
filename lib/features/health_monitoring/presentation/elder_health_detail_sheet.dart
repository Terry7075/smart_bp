import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../health_monitoring_models.dart';
import '../health_monitoring_provider.dart';

/// 志工點某位長輩後彈出的底部 Sheet：指標歷史 + 連線狀態。
class ElderHealthDetailSheet extends ConsumerStatefulWidget {
  const ElderHealthDetailSheet({
    super.key,
    required this.summary,
  });

  final ElderHealthSummary summary;

  static Future<void> show(BuildContext context, ElderHealthSummary summary) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ElderHealthDetailSheet(summary: summary),
    );
  }

  @override
  ConsumerState<ElderHealthDetailSheet> createState() =>
      _ElderHealthDetailSheetState();
}

class _ElderHealthDetailSheetState
    extends ConsumerState<ElderHealthDetailSheet> {
  String _selectedType = HealthMetricType.heartRate;

  void _selectType(String type) {
    setState(() => _selectedType = type);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final conn = summary.connection;
    final lastSync = conn?.lastSyncAt;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                    summary.elderName.isNotEmpty
                        ? summary.elderName[0]
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.elderName,
                          style: theme.textTheme.titleMedium),
                      if (lastSync != null)
                        Text(
                          '最後同步：${DateFormat('MM/dd HH:mm').format(lastSync)}',
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        Text(
                          conn == null ? '尚未綁定 Health Connect' : '從未同步',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.orange),
                        ),
                    ],
                  ),
                ),
                if (conn != null)
                  Icon(
                    conn.isLinked
                        ? Icons.check_circle_outline
                        : Icons.link_off,
                    color: conn.isLinked ? Colors.green : Colors.grey,
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          // 指標 type 選擇器
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: HealthMetricType.all
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(HealthMetricType.label(t)),
                          selected: _selectedType == t,
                          onSelected: (_) => _selectType(t),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 歷史清單
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final historyAsync = ref.watch(
                  elderMetricHistoryProvider(
                    (widget.summary.elderId, _selectedType),
                  ),
                );
                return historyAsync.when(
                  data: (pts) => pts.isEmpty
                      ? const Center(child: Text('此指標無資料'))
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: pts.length,
                          itemBuilder: (_, i) => _HistoryRow(pt: pts[i]),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('載入失敗：$e')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.pt});

  final HealthMetricPoint pt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        '${pt.value.toStringAsFixed(1)} ${HealthMetricType.unitFor(pt.metricType)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        DateFormat('MM/dd HH:mm').format(pt.recordedAt),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
