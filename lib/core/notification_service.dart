import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 通知排程結果（給呼叫端做使用者回饋用）。
///
/// 長輩端僅排程「每日吃藥時段」；領藥物流由志工端處理，不再排本機領藥鬧鐘。
class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.granted,
    required this.medicationCount,
  });

  final bool granted;
  final int medicationCount;

  bool get hasAnyScheduled => medicationCount > 0;
}

/// 吃藥提醒 payload（**舊**格式前綴）：`mindu_checkin|<prescriptionId>|<HH:mm>`
///
/// 新版改用 JSON（見 [_buildCheckinPayload]）；此前綴僅保留給「升級前已排程、
/// 尚未觸發」的舊通知做向後相容解析。
const String kPayloadMinduCheckinPrefix = 'mindu_checkin|';

/// 健康告警通知 payload（**舊**格式前綴）：`health_alert|<elderId>`
const String kPayloadHealthAlertPrefix = 'health_alert|';

/// 柑仔店／志工 FCM 點擊導航：`mindu_shop|<route>`
const String kPayloadMinduShopPrefix = 'mindu_shop|';

/// payload JSON 的 type 值。
const String _kTypeCheckin = 'mindu_checkin';
const String _kTypeHealthAlert = 'health_alert';

/// 「明德 e 達人」本機通知排程服務（單例）。
///
/// **多重藥單**：每張藥單（`prescriptionId`）獨佔一組 integer notification id，
/// 不再呼叫 [cancelAll] 清空全部提醒；改用 [cancelRemindersByPrescriptionId]。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 由 App 注入：`go('/path')` 之類，通常綁 [GoRouter.go]。
  void Function(String location)? _navigate;

  /// 在 [_navigate] 尚未綁定時收到的通知點擊，先暫存待綁定後補跳。
  ///
  /// 為什麼需要？冷啟動時「點通知 → App 啟動 → handleLaunchNotificationIfAny」
  /// 與 main.dart 內 `bindNavigate` 都掛在 post-frame callback，順序不保證；
  /// 若點擊先到、_navigate 還是 null，原本的 `_navigate?.call()` 會直接被丟掉，
  /// 長輩點了通知卻停在首頁。改成暫存後，bind 完成立刻補跳。
  String? _pendingRoute;

  void bindNavigate(void Function(String location) navigate) {
    _navigate = navigate;
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      navigate(pending);
    }
  }

  /// 導航：已綁定就直接跳，否則暫存待 [bindNavigate] 後補跳。
  void _go(String route) {
    final nav = _navigate;
    if (nav != null) {
      nav(route);
    } else {
      _pendingRoute = route;
    }
  }

  void handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // 1) 新版 JSON 格式。
    final decoded = _tryDecodePayload(payload);
    if (decoded != null) {
      switch (decoded['type']) {
        case _kTypeCheckin:
          final rxId = decoded['rx']?.toString() ?? '';
          final slot = decoded['slot']?.toString() ?? '';
          if (rxId.isEmpty) return;
          _goCheckin(rxId, slot);
          return;
        case _kTypeHealthAlert:
          _go('/');
          return;
      }
    }

    // 2) 舊版 pipe 格式（升級前已排程、尚未觸發的通知）。
    if (payload.startsWith(kPayloadMinduCheckinPrefix)) {
      final rest = payload.substring(kPayloadMinduCheckinPrefix.length);
      final sep = rest.lastIndexOf('|');
      if (sep <= 0 || sep >= rest.length - 1) return;
      _goCheckin(rest.substring(0, sep), rest.substring(sep + 1));
      return;
    }

    if (payload.startsWith(kPayloadHealthAlertPrefix)) {
      _go('/');
      return;
    }

    // 領藥提醒：回首頁即可。
    if (payload.startsWith('mindu_pickup|')) {
      _navigate?.call('/home');
      return;
    }

    // 訂單狀態通知：跳轉訂單詳情頁。
    if (payload.startsWith('mindu_order|')) {
      final orderId = payload.substring('mindu_order|'.length);
      if (orderId.isNotEmpty) {
        _go('/shop/orders/$orderId');
      }
      return;
    }

    // 柑仔店 FCM／本機推播：跳轉志工採買或自訂路由。
    if (payload.startsWith(kPayloadMinduShopPrefix)) {
      final route = payload.substring(kPayloadMinduShopPrefix.length);
      if (route.isNotEmpty) {
        _go(route);
      }
    }
  }

  /// 由 FCM 點擊或前景 handler 導航（[bindNavigate] 前會暫存）。
  void navigateToRoute(String route) => _go(route);

  void _goCheckin(String rxId, String slotTime) {
    final encRx = Uri.encodeComponent(rxId);
    final encSlot = Uri.encodeComponent(slotTime);
    _go('/medication-checkin?prescriptionId=$encRx&slotTime=$encSlot');
  }

  Map<String, dynamic>? _tryDecodePayload(String payload) {
    if (!payload.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _buildCheckinPayload(String prescriptionId, String slot) =>
      jsonEncode({'type': _kTypeCheckin, 'rx': prescriptionId, 'slot': slot});

  static String _buildHealthAlertPayload(String? elderId) =>
      jsonEncode({'type': _kTypeHealthAlert, 'elder': elderId ?? ''});

  Future<void> handleLaunchNotificationIfAny() async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp ?? false) {
      if (response != null) {
        handleNotificationTap(response);
      }
    }
  }

  static const String _medicationChannelId = 'mindu_medication_reminder';
  static const String _medicationChannelName = '吃藥時間提醒';
  static const String _medicationChannelDesc = '每天在固定時間叮咚提醒長輩按時服藥';

  static const String _pickupChannelId = 'mindu_prescription_pickup';
  static const String _pickupChannelName = '回診領藥提醒';
  static const String _pickupChannelDesc = '在下次領藥日當天提醒長輩記得回診拿藥';

  static const String _orderChannelId = 'mindu_order_status';
  static const String _orderChannelName = '物資訂單狀態';
  static const String _orderChannelDesc = '志工接單或完成訂單時即時通知長輩';

  /// 每張藥單最多排的「吃藥時段」數（對應連續 notification id）。
  static const int maxMedicationSlotsPerPrescription = 12;

  /// 取消時清掃的 id 範圍（**必須 ≥ 任何歷史版本的 max**）。
  ///
  /// 為什麼跟 [maxMedicationSlotsPerPrescription] 分開？
  /// - 若哪天把 max 調小（例如 12 → 6），舊版用 base+6..base+11 排的提醒
  ///   就會落在新的取消迴圈範圍外、永遠清不掉，造成殘留鬧鐘。
  /// - 用一個固定且偏大的清掃範圍（24）涵蓋所有歷史值，永遠安全。
  static const int _cancelSlotRange = 24;

  /// 由 [prescriptionId] 推導穩定的 base notification id（31-bit 正整數）。
  ///
  /// 不同 UUID 極少碰撞；若碰撞也只會互相覆蓋同一組 id，屬可接受風險。
  static int baseNotificationId(String prescriptionId) {
    var h = 0;
    for (final unit in prescriptionId.codeUnits) {
      h = 0x1fffffff & (h * 31 + unit);
    }
    h = h & 0x7fffffff;
    // 避開過小的 system id，並留在 Dart / Android int 安全範圍。
    const minBase = 500000;
    return minBase + (h % 2100000000);
  }

  /// 這張藥單目前排程會用到的通知 id（僅吃藥時段）。
  static List<int> allNotificationIdsFor(String prescriptionId) {
    final base = baseNotificationId(prescriptionId);
    return List.generate(
      maxMedicationSlotsPerPrescription,
      (i) => base + i,
    );
  }

  /// 取消時要清掃的通知 id（範圍比排程用的 max 大，涵蓋歷史殘留）。
  static List<int> _cancelNotificationIdsFor(String prescriptionId) {
    final base = baseNotificationId(prescriptionId);
    return List.generate(_cancelSlotRange, (i) => base + i);
  }

  static int medicationNotificationId(String prescriptionId, int slotIndex) =>
      baseNotificationId(prescriptionId) + slotIndex;

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: handleNotificationTap,
    );

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      // Android 12+：另外請求「精準鬧鐘」授權。沒這個就算 POST_NOTIFICATIONS
      // 拿到了，exactAllowWhileIdle 仍會被降級成 inexact，吃藥提醒可能延遲。
      // requestExactAlarmsPermission 內部會看 manifest 有沒有 USE_EXACT_ALARM
      // （API 33+ 自動授權）或 SCHEDULE_EXACT_ALARM（會跳系統設定畫面）。
      try {
        await android.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('[NotificationService] requestExactAlarmsPermission: $e');
      }
      return granted ?? true;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return false;
    final granted = await ios.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  /// 將 FCM [RemoteMessage] 轉成本機高優先通知（前景／背景 data-only 用）。
  Future<void> showShopPushFromRemoteMessage(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;
    final title = n?.title ?? data['title'] ?? '明德 e 達人';
    final body = n?.body ?? data['body_text'] ?? data['body'] ?? '您有新的代購通知';
    final route = data['route'] ?? '/volunteer/shop-orders';
    final orderId = data['order_id'];
    final idSeed = orderId ?? message.messageId ?? route;
    await showShopPushNotification(
      title: title,
      body: body,
      route: route,
      notificationId: 320000 + (idSeed.hashCode.abs() % 80000),
    );
  }

  /// 柑仔店／志工推播（FCM 前景或 Realtime 補強）。
  Future<void> showShopPushNotification({
    required String title,
    required String body,
    String route = '/volunteer/shop-orders',
    int notificationId = 320001,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _orderChannelId,
        _orderChannelName,
        channelDescription: _orderChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final payload = '$kPayloadMinduShopPrefix$route';
    try {
      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] showShopPushNotification failed: $e');
    }
  }

  /// 即時顯示訂單狀態通知（不排程，立即出現）。
  ///
  /// [orderId] 可作為 payload，點擊後跳轉 `/shop/orders/:id`。
  /// [route] 若設定則使用 `mindu_shop|<route>`（志工採買清單等）。
  Future<void> showOrderStatusNotification({
    required String title,
    required String body,
    String? orderId,
    String? route,
    int notificationId = 1,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _orderChannelId,
        _orderChannelName,
        channelDescription: _orderChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final String? payload;
    if (route != null && route.isNotEmpty) {
      payload = '$kPayloadMinduShopPrefix$route';
    } else if (orderId != null) {
      payload = 'mindu_order|$orderId';
    } else {
      payload = null;
    }
    try {
      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] showOrderStatusNotification failed: $e');
    }
  }

  /// 緊急／除錯用：取消「全部」本機排程與通知。
  ///
  /// 正常業務請改用 [cancelRemindersByPrescriptionId]，避免洗掉其他藥單。
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await _plugin.cancelAll();
  }

  /// 僅移除與 [prescriptionId] 相關的吃藥時段排程。
  Future<void> cancelRemindersByPrescriptionId(String prescriptionId) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    for (final notificationId in _cancelNotificationIdsFor(prescriptionId)) {
      await _plugin.cancel(id: notificationId);
    }
  }

  /// 為單張藥單排程每日吃藥提醒（payload 導向打卡頁）。
  Future<NotificationScheduleResult> schedulePrescriptionReminders({
    required String prescriptionId,
    required List<String> takeMedicineTimes,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const NotificationScheduleResult(
        granted: false,
        medicationCount: 0,
      );
    }

    await cancelRemindersByPrescriptionId(prescriptionId);

    final granted = await requestPermission();
    if (!granted) {
      return const NotificationScheduleResult(
        granted: false,
        medicationCount: 0,
      );
    }

    final medicationCount = await _scheduleMedicationReminders(
      prescriptionId: prescriptionId,
      times: takeMedicineTimes,
    );

    return NotificationScheduleResult(
      granted: true,
      medicationCount: medicationCount,
    );
  }

  Future<int> _scheduleMedicationReminders({
    required String prescriptionId,
    required List<String> times,
  }) async {
    if (times.isEmpty) return 0;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _medicationChannelId,
        _medicationChannelName,
        channelDescription: _medicationChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        // 鎖屏時也用整頁提醒搶出來，避免長輩錯過吃藥（醫療提醒屬合理使用）。
        fullScreenIntent: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    var scheduled = 0;
    for (var i = 0; i < times.length && i < maxMedicationSlotsPerPrescription; i++) {
      final hm = _parseHourMinute(times[i]);
      if (hm == null) continue;

      final fireAt = _nextInstanceOfTime(hm.$1, hm.$2);
      final nid = medicationNotificationId(prescriptionId, i);
      final payload = _buildCheckinPayload(prescriptionId, times[i]);

      try {
        await _plugin.zonedSchedule(
          id: nid,
          title: '⏰ 吃藥時間到囉！',
          body: '到了 ${times[i]} 該吃這包藥了，記得配溫水慢慢吃。',
          scheduledDate: fireAt,
          notificationDetails: details,
          // 用 exactAllowWhileIdle：醫療提醒必須準時叮咚，不能被 doze 延遲。
          // 對應的 USE_EXACT_ALARM / SCHEDULE_EXACT_ALARM 已在 AndroidManifest 宣告，
          // 並在 requestPermission() 內主動申請。
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        scheduled++;
      } on PlatformException catch (e, st) {
        // 沒有精準鬧鐘權限時，Android 會丟 exact_alarms_not_permitted；
        // 降級成 inexact 再排一次，避免完全沒提醒。
        if (e.code == 'exact_alarms_not_permitted') {
          debugPrint(
            '[NotificationService] 精準鬧鐘權限被拒，改用 inexact 排程 ${times[i]}',
          );
          try {
            await _plugin.zonedSchedule(
              id: nid,
              title: '⏰ 吃藥時間到囉！',
              body: '到了 ${times[i]} 該吃這包藥了，記得配溫水慢慢吃。',
              scheduledDate: fireAt,
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
              payload: payload,
            );
            scheduled++;
          } catch (e2, st2) {
            debugPrint(
              '[NotificationService] 服藥提醒 inexact fallback 仍失敗 ${times[i]}: $e2\n$st2',
            );
          }
        } else {
          debugPrint(
            '[NotificationService] 服藥提醒排程失敗 ${times[i]}: $e\n$st',
          );
        }
      } catch (e, st) {
        debugPrint('[NotificationService] 服藥提醒排程失敗 ${times[i]}: $e\n$st');
      }
    }
    return scheduled;
  }

  (int, int)? _parseHourMinute(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // --------------------------------------------------------------------------
  // 健康告警通知（outbox → 本機通知）
  // --------------------------------------------------------------------------

  static const String _healthAlertChannelId = 'mindu_health_alert';
  static const String _healthAlertChannelName = '長輩健康告警';

  static int _healthAlertNotificationId(String outboxId) {
    var h = 0;
    for (final unit in outboxId.codeUnits) {
      h = 0x1fffffff & (h * 31 + unit);
    }
    return 0x40000000 | (h & 0x3fffffff); // 高位元確保不與藥單 id 撞
  }

  /// 顯示一則健康告警即時通知，並可透過 [elderId] 導航到監測 Tab。
  Future<void> showHealthAlert({
    required String outboxId,
    required String title,
    required String body,
    String? elderId,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _healthAlertChannelId,
        _healthAlertChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: _healthAlertNotificationId(outboxId),
      title: title,
      body: body,
      notificationDetails: details,
      payload: _buildHealthAlertPayload(elderId),
    );
  }
}
