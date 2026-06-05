import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 端到端 Realtime 延遲量測（僅在 kDebugMode 生效）。
///
/// 使用方式：
/// 1. 長輩送出需求時呼叫 [markSent]。
/// 2. 志工端 Realtime 收到事件時呼叫 [markReceived]。
/// 3. 透過 [latencyMs] 取得最近一次延遲（ms）。
class RealtimeLatencyState {
  const RealtimeLatencyState({
    this.sentAt,
    this.receivedAt,
    this.latencyMs,
    this.sampleCount = 0,
    this.avgLatencyMs,
  });

  final DateTime? sentAt;
  final DateTime? receivedAt;
  final int? latencyMs;
  final int sampleCount;
  final double? avgLatencyMs;

  RealtimeLatencyState copyWith({
    DateTime? sentAt,
    DateTime? receivedAt,
    int? latencyMs,
    int? sampleCount,
    double? avgLatencyMs,
  }) =>
      RealtimeLatencyState(
        sentAt: sentAt ?? this.sentAt,
        receivedAt: receivedAt ?? this.receivedAt,
        latencyMs: latencyMs ?? this.latencyMs,
        sampleCount: sampleCount ?? this.sampleCount,
        avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      );
}

class RealtimeLatencyNotifier extends Notifier<RealtimeLatencyState> {
  @override
  RealtimeLatencyState build() => const RealtimeLatencyState();

  /// 長輩端送出請求時記錄時間戳記。
  void markSent() {
    if (!kDebugMode) return;
    state = state.copyWith(sentAt: DateTime.now(), receivedAt: null, latencyMs: null);
  }

  /// 志工端 Realtime 收到事件時記錄。
  void markReceived() {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final sent = state.sentAt;
    if (sent == null) {
      state = state.copyWith(receivedAt: now);
      return;
    }
    final ms = now.difference(sent).inMilliseconds;
    final n = state.sampleCount + 1;
    final prevAvg = state.avgLatencyMs ?? 0;
    final newAvg = (prevAvg * (n - 1) + ms) / n;
    state = state.copyWith(
      receivedAt: now,
      latencyMs: ms,
      sampleCount: n,
      avgLatencyMs: newAvg,
    );
    debugPrint('[Realtime] latency: ${ms}ms (avg: ${newAvg.toStringAsFixed(0)}ms, n=$n)');
  }
}

final realtimeLatencyProvider =
    NotifierProvider<RealtimeLatencyNotifier, RealtimeLatencyState>(
  RealtimeLatencyNotifier.new,
);
