import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../health_monitoring_models.dart';
import '../health_monitoring_provider.dart';
import '../health_sync_service.dart';

/// 長輩底欄「監測」頁
///
/// States:
///   1. Not linked  → show "Connect Fitbit" button (launches Google OAuth)
///   2. Linked      → show last-sync time + "Sync Now" button
///   3. Revoked     → show "Re-authorize" button
class ElderMonitoringTab extends ConsumerStatefulWidget {
  const ElderMonitoringTab({super.key});

  @override
  ConsumerState<ElderMonitoringTab> createState() => _ElderMonitoringTabState();
}

class _ElderMonitoringTabState extends ConsumerState<ElderMonitoringTab> {
  bool _busy = false;
  String? _statusMessage;
  bool _statusOk = true;

  // ── OAuth authorize (first time) ──────────────────────────────────────────

  Future<void> _authorize() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final svc = ref.read(googleHealthApiServiceProvider);
      // google_sign_in v7: initialize + authenticate + authorizeScopes
      await svc.authorize();

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw Exception('請先登入。');

      // Mark connection as linked (no raw token storage needed)
      await ref.read(healthMonitoringRepoProvider).upsertConnection(
            userId: uid,
            status: HealthConnectionStatus.linked,
            clearLastError: true,
          );
      ref.invalidate(myHealthConnectionProvider);

      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = 'Fitbit 帳號連結成功！請點「立即同步」上傳健康資料。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = '授權失敗：$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Sync now ──────────────────────────────────────────────────────────────

  Future<void> _sync() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    final svc = ref.read(healthSyncServiceProvider);
    final out = await svc.syncNow();

    ref.invalidate(myLatestMetricsProvider);
    ref.invalidate(myHealthConnectionProvider);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusOk = out.ok || out.result == SyncResult.noData;
      _statusMessage = switch (out.result) {
        SyncResult.success => '已同步 ${out.count} 筆資料 ✓',
        SyncResult.noData => '連線正常，24 小時內無新資料',
        SyncResult.noPermission => out.message ?? '請先連結 Fitbit 帳號',
        SyncResult.error => out.message ?? '發生未知錯誤',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final connAsync = ref.watch(myHealthConnectionProvider);
    final metricsAsync = ref.watch(myLatestMetricsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('穿戴監測'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myLatestMetricsProvider);
          ref.invalidate(myHealthConnectionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionCard(
              connAsync: connAsync,
              busy: _busy,
              onAuthorize: _authorize,
              onSync: _sync,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              _StatusBanner(message: _statusMessage!, ok: _statusOk),
            ],
            const SizedBox(height: 16),
            _MetricsSection(metricsAsync: metricsAsync),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connection card
// ---------------------------------------------------------------------------

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connAsync,
    required this.busy,
    required this.onAuthorize,
    required this.onSync,
  });

  final AsyncValue<HealthConnection?> connAsync;
  final bool busy;
  final VoidCallback onAuthorize;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Fitbit 連線狀態', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            connAsync.when(
              data: (conn) => _ConnectionStatus(conn: conn),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('載入失敗：$e',
                  style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
            connAsync.when(
              data: (conn) => _ActionButton(
                conn: conn,
                busy: busy,
                onAuthorize: onAuthorize,
                onSync: onSync,
              ),
              loading: () => const SizedBox.shrink(),
              error: (err, st) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({this.conn});
  final HealthConnection? conn;

  @override
  Widget build(BuildContext context) {
    if (conn == null || !conn!.isLinked) {
      return const _StatusRow(
        icon: Icons.link_off,
        color: Colors.grey,
        label: '尚未連結 Fitbit 帳號',
      );
    }
    final last = conn!.lastSyncAt;
    final label = last == null
        ? '已連結（從未同步）'
        : '已連結・最後同步 ${_fmt(last)}';
    return _StatusRow(
      icon: Icons.check_circle_outline,
      color: Colors.green,
      label: label,
    );
  }

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MM/dd HH:mm').format(dt);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.conn,
    required this.busy,
    required this.onAuthorize,
    required this.onSync,
  });

  final HealthConnection? conn;
  final bool busy;
  final VoidCallback onAuthorize;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final linked = conn != null && conn!.isLinked;

    if (!linked) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onAuthorize,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.fitbit),
          label: Text(busy ? '授權中…' : '使用 Google 帳號連結 Fitbit'),
        ),
      );
    }

    // Already linked: offer re-authorize (outlined) + sync (filled) side by side
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onAuthorize,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新授權'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onSync,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            label: Text(busy ? '同步中…' : '立即同步'),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(label)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Metrics section
// ---------------------------------------------------------------------------

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.metricsAsync});
  final AsyncValue<Map<String, HealthMetricPoint>> metricsAsync;

  @override
  Widget build(BuildContext context) {
    return metricsAsync.when(
      data: (map) {
        if (map.isEmpty) return const _EmptyMetrics();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('最近健康資料',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...HealthMetricType.all
                .map((type) => _MetricCard(type: type, point: map[type])),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(child: Text('讀取失敗：$e')),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.type, this.point});
  final String type;
  final HealthMetricPoint? point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = point != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(_iconFor(type),
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(HealthMetricType.label(type)),
        trailing: hasData
            ? Text(
                '${point!.value.toStringAsFixed(1)} ${HealthMetricType.unitFor(type)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Text('無資料',
                style: TextStyle(color: theme.colorScheme.outline)),
        subtitle: hasData
            ? Text(_relativeTime(point!.recordedAt),
                style: const TextStyle(fontSize: 11))
            : null,
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        HealthMetricType.heartRate => Icons.favorite_outline,
        HealthMetricType.restingHeartRate => Icons.bedtime_outlined,
        HealthMetricType.steps => Icons.directions_walk,
        HealthMetricType.sleepMinutes => Icons.nights_stay_outlined,
        HealthMetricType.bloodOxygen => Icons.water_drop_outlined,
        _ => Icons.monitor_heart_outlined,
      };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    return '${diff.inDays} 天前';
  }
}

class _EmptyMetrics extends StatelessWidget {
  const _EmptyMetrics();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.monitor_heart_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('尚無健康資料', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              '連結 Fitbit 帳號後點「立即同步」即可上傳資料',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status banner
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.ok});
  final String message;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? Colors.green : Colors.red),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            color: ok ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
