import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 通知排程結果（給呼叫端做使用者回饋用）。
///
/// - [granted] 是否取得通知權限。
/// - [medicationCount] 已成功排定的「每日服藥提醒」筆數。
/// - [pickupScheduled] 是否成功排定「下次領藥日提醒」。
class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.granted,
    required this.medicationCount,
    required this.pickupScheduled,
  });

  final bool granted;
  final int medicationCount;
  final bool pickupScheduled;

  bool get hasAnyScheduled => medicationCount > 0 || pickupScheduled;
}

/// 吃藥提醒 payload：`mindu_checkin|<prescriptionId>|<HH:mm>`
///
/// 舊格式相容：`medication:HH:mm`（無藥單 ID）仍可解析時間但不會帶 prescription。
const String kPayloadMinduCheckinPrefix = 'mindu_checkin|';

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

  void bindNavigate(void Function(String location) navigate) {
    _navigate = navigate;
  }

  void handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith(kPayloadMinduCheckinPrefix)) {
      final rest = payload.substring(kPayloadMinduCheckinPrefix.length);
      final sep = rest.lastIndexOf('|');
      if (sep <= 0 || sep >= rest.length - 1) return;
      final rxId = rest.substring(0, sep);
      final slotTime = rest.substring(sep + 1);
      final encRx = Uri.encodeComponent(rxId);
      final encSlot = Uri.encodeComponent(slotTime);
      _navigate?.call('/medication-checkin?prescriptionId=$encRx&slotTime=$encSlot');
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
        _navigate?.call('/shop/orders/$orderId');
      }
    }
  }

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

  /// 領藥提醒與吃藥時段 id 的固定位移（避免碰撞）。
  static const int _pickupIdOffset = 40;

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

  /// 這張藥單所有可能用到的通知 id（吃藥 × N + 領藥 × 1）。
  static List<int> allNotificationIdsFor(String prescriptionId) {
    final base = baseNotificationId(prescriptionId);
    return [
      ...List.generate(maxMedicationSlotsPerPrescription, (i) => base + i),
      base + _pickupIdOffset,
    ];
  }

  static int medicationNotificationId(String prescriptionId, int slotIndex) =>
      baseNotificationId(prescriptionId) + slotIndex;

  static int pickupNotificationId(String prescriptionId) =>
      baseNotificationId(prescriptionId) + _pickupIdOffset;

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

  /// 即時顯示訂單狀態通知（不排程，立即出現）。
  ///
  /// [orderId] 可作為 payload，點擊後跳轉 `/shop/orders/:id`。
  Future<void> showOrderStatusNotification({
    required String title,
    required String body,
    String? orderId,
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

    final payload = orderId != null ? 'mindu_order|$orderId' : null;
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

  /// 僅移除與 [prescriptionId] 相關的排程（吃藥時段 + 領藥日）。
  Future<void> cancelRemindersByPrescriptionId(String prescriptionId) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    for (final notificationId in allNotificationIdsFor(prescriptionId)) {
      await _plugin.cancel(id: notificationId);
    }
  }

  /// 為單張藥單排程：
  /// 1. 先 [cancelRemindersByPrescriptionId]（同一張藥單重複按「完成」時覆蓋舊排程）。
  /// 2. 取得通知權限。
  /// 3. 每日吃藥提醒（payload 導向打卡頁）。
  /// 4. 領藥日單次提醒。
  Future<NotificationScheduleResult> schedulePrescriptionReminders({
    required String prescriptionId,
    required List<String> takeMedicineTimes,
    DateTime? pickupDate,
    String? hospitalName,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const NotificationScheduleResult(
        granted: false,
        medicationCount: 0,
        pickupScheduled: false,
      );
    }

    await cancelRemindersByPrescriptionId(prescriptionId);

    final granted = await requestPermission();
    if (!granted) {
      return const NotificationScheduleResult(
        granted: false,
        medicationCount: 0,
        pickupScheduled: false,
      );
    }

    final medicationCount = await _scheduleMedicationReminders(
      prescriptionId: prescriptionId,
      times: takeMedicineTimes,
    );
    final pickupOk = pickupDate != null
        ? await _schedulePickupReminder(
            prescriptionId: prescriptionId,
            pickupDate: pickupDate,
            hospitalName: hospitalName,
          )
        : false;

    return NotificationScheduleResult(
      granted: true,
      medicationCount: medicationCount,
      pickupScheduled: pickupOk,
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
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
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
      final payload =
          '$kPayloadMinduCheckinPrefix$prescriptionId|${times[i]}';

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
      } catch (e, st) {
        debugPrint('[NotificationService] 服藥提醒排程失敗 ${times[i]}: $e\n$st');
      }
    }
    return scheduled;
  }

  Future<bool> _schedulePickupReminder({
    required String prescriptionId,
    required DateTime pickupDate,
    String? hospitalName,
  }) async {
    final fireAt = tz.TZDateTime(
      tz.local,
      pickupDate.year,
      pickupDate.month,
      pickupDate.day,
      9,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (!fireAt.isAfter(now)) {
      debugPrint(
        '[NotificationService] 領藥日已過，不排程：$pickupDate (now=$now)',
      );
      return false;
    }

    final body = (hospitalName != null && hospitalName.trim().isNotEmpty)
        ? '今天記得回 $hospitalName 拿藥喔！別忘了帶健保卡。'
        : '今天是回診拿藥的日子，記得別忘了帶健保卡喔！';

    final nid = pickupNotificationId(prescriptionId);
    final payload = 'mindu_pickup|$prescriptionId';

    try {
      await _plugin.zonedSchedule(
        id: nid,
        title: '💊 今天該回診領藥囉！',
        body: body,
        scheduledDate: fireAt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _pickupChannelId,
            _pickupChannelName,
            channelDescription: _pickupChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (e, st) {
      debugPrint('[NotificationService] 領藥日提醒排程失敗：$e\n$st');
      return false;
    }
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
}
