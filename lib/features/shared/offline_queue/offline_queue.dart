import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// 一筆待送出的 demand 需求（序列化為 JSON 字串）。
class OfflineDemandItem {
  const OfflineDemandItem({
    required this.clientRequestId,
    required this.userId,
    required this.productName,
    required this.quantity,
    this.productId,
    this.unitPrice,
    required this.createdAt,
    this.retryCount = 0,
  });

  final String clientRequestId; // 冪等鍵（UUID v4）
  final String userId;
  final String productName;
  final int quantity;
  final String? productId;
  final double? unitPrice;
  final DateTime createdAt;
  final int retryCount;

  Map<String, dynamic> toJson() => {
        'clientRequestId': clientRequestId,
        'userId': userId,
        'productName': productName,
        'quantity': quantity,
        if (productId != null) 'productId': productId,
        if (unitPrice != null) 'unitPrice': unitPrice,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineDemandItem.fromJson(Map<String, dynamic> j) =>
      OfflineDemandItem(
        clientRequestId: j['clientRequestId'] as String,
        userId: j['userId'] as String,
        productName: j['productName'] as String,
        quantity: (j['quantity'] as num).toInt(),
        productId: j['productId'] as String?,
        unitPrice: (j['unitPrice'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
      );

  OfflineDemandItem copyWith({int? retryCount}) => OfflineDemandItem(
        clientRequestId: clientRequestId,
        userId: userId,
        productName: productName,
        quantity: quantity,
        productId: productId,
        unitPrice: unitPrice,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
}

/// Hive 離線佇列：
/// - 網路或 Supabase 寫入失敗時 [enqueue]。
/// - App 啟動或網路恢復時 [flush]。
/// - 使用 `client_request_id` 保證冪等（DB unique index 存在時）。
class OfflineQueue {
  static const _boxName = 'offline_demand_queue';
  static const _maxRetry = 5;

  static OfflineQueue? _instance;
  late Box<String> _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  /// 供 UI 監聽待送數量，ValueListenableBuilder 可直接使用。
  final ValueNotifier<int> pendingNotifier = ValueNotifier(0);

  OfflineQueue._();

  static Future<OfflineQueue> init() async {
    if (_instance != null) return _instance!;
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    final q = OfflineQueue._();
    q._box = box;
    q.pendingNotifier.value = box.length; // 還原上次未送完的數量
    q._startConnectivityWatch();
    _instance = q;
    // 啟動時主動 flush（延遲 1.5 秒等 Supabase session 就緒）
    Future.delayed(const Duration(milliseconds: 1500), q.flush);
    return q;
  }

  static OfflineQueue get instance {
    assert(_instance != null, 'OfflineQueue.init() must be called first');
    return _instance!;
  }

  int get pendingCount => _box.length;

  /// 將一筆需求加入佇列（同時生成 clientRequestId）。
  Future<void> enqueue({
    required String userId,
    required String productName,
    required int quantity,
    String? productId,
    double? unitPrice,
  }) async {
    final item = OfflineDemandItem(
      clientRequestId: const Uuid().v4(),
      userId: userId,
      productName: productName,
      quantity: quantity,
      productId: productId,
      unitPrice: unitPrice,
      createdAt: DateTime.now(),
    );
    await _box.put(item.clientRequestId, jsonEncode(item.toJson()));
    pendingNotifier.value = _box.length;
    if (kDebugMode) debugPrint('[OfflineQueue] enqueued: ${item.productName}');
  }

  /// 嘗試送出佇列中所有項目（冪等）。
  Future<void> flush() async {
    if (_flushing || _box.isEmpty) return;
    _flushing = true;
    if (kDebugMode) debugPrint('[OfflineQueue] flushing ${_box.length} items');
    final keys = _box.keys.toList();
    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      OfflineDemandItem item;
      try {
        item = OfflineDemandItem.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        await _box.delete(key);
        continue;
      }
      if (item.retryCount >= _maxRetry) {
        await _box.delete(key);
        continue;
      }
      final ok = await _sendOne(item);
      if (ok) {
        await _box.delete(key);
      } else {
        await _box.put(key,
            jsonEncode(item.copyWith(retryCount: item.retryCount + 1).toJson()));
      }
    }
    pendingNotifier.value = _box.length;
    _flushing = false;
  }

  Future<bool> _sendOne(OfflineDemandItem item) async {
    try {
      final client = Supabase.instance.client;

      // 1. 找到或建立 draft demand_record
      final existing = await client
          .from('demand_records')
          .select('id')
          .eq('user_id', item.userId)
          .eq('status', 'draft')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String recordId;
      if (existing != null) {
        recordId = existing['id'] as String;
      } else {
        final created = await client
            .from('demand_records')
            .insert({'user_id': item.userId, 'status': 'draft'})
            .select('id')
            .single();
        recordId = created['id'] as String;
      }

      // 2. 插入品項（帶 client_request_id 作冪等鍵）
      await client.from('demand_record_items').upsert(
        {
          'demand_record_id': recordId,
          'product_name': item.productName,
          'quantity': item.quantity,
          if (item.productId != null) 'product_id': item.productId,
          if (item.unitPrice != null) 'unit_price': item.unitPrice,
          'client_request_id': item.clientRequestId,
        },
        onConflict: 'client_request_id',
        ignoreDuplicates: true,
      );

      if (kDebugMode) {
        debugPrint('[OfflineQueue] sent: ${item.productName}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineQueue] send failed: $e');
      return false;
    }
  }

  void _startConnectivityWatch() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork && _box.isNotEmpty) {
        await flush();
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _box.close();
    _instance = null;
  }
}
