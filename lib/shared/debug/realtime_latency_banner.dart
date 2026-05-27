import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/shared/debug/realtime_latency_tracker.dart';

/// Debug-only 浮動 banner，顯示最近一次 Realtime 端到端延遲。
/// 僅在 kDebugMode 時顯示，不影響正式 UI。
class RealtimeLatencyBanner extends ConsumerWidget {
  const RealtimeLatencyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final latency = ref.watch(realtimeLatencyProvider);
    final ms = latency.latencyMs;
    final avg = latency.avgLatencyMs;
    final n = latency.sampleCount;

    if (ms == null && n == 0) return const SizedBox.shrink();

    final color = ms != null && ms < 500
        ? const Color(0xFF2E7D32)
        : ms != null && ms < 1500
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ms != null ? '⚡ ${ms}ms' : '⏳ 等待中',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (avg != null)
                Text(
                  '均 ${avg.toStringAsFixed(0)}ms (n=$n)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
