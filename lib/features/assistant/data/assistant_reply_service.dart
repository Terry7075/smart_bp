import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_bp/features/assistant/domain/assistant_nav_action.dart';
import 'package:smart_bp/features/assistant/domain/assistant_reply.dart';
import 'package:smart_bp/features/assistant/domain/assistant_snapshot.dart';
import 'package:smart_bp/features/shop/domain/shop_order_models.dart';
import 'package:smart_bp/features/shop/domain/shop_order_status.dart';
import 'package:smart_bp/features/volunteer/volunteer_task.dart';

/// 依關鍵字與 [AssistantSnapshot] 產生回覆（不呼叫外部 AI）。
class AssistantReplyService {
  const AssistantReplyService();

  static const _navHome = AssistantNavAction(label: '前往首頁', route: '/home', homeTab: 0);
  static const _navShop = AssistantNavAction(label: '前往柑仔店', route: '/shop');
  static const _navShopOrders = AssistantNavAction(label: '查看代購紀錄', route: '/shop/orders');
  static const _navHealthTab = AssistantNavAction(label: '前往健康', route: '/home', homeTab: 3);
  static const _navHealthScan = AssistantNavAction(label: '前往健康掃描', route: '/health-scan');
  static const _navTransport = AssistantNavAction(label: '前往交通', route: '/home', homeTab: 2);
  static const _navLearning = AssistantNavAction(label: '前往學習', route: '/home', homeTab: 4);
  static const _navEvents = AssistantNavAction(label: '前往活動', route: '/home', homeTab: 5);
  static const _navProfile = AssistantNavAction(label: '前往個人資料', route: '/profile');

  AssistantReply reply(String question, AssistantSnapshot snapshot) {
    final normalized = question.trim().toLowerCase().replaceAll(' ', '');

    if (_matchAny(normalized, ['你好', '嗨', '哈囉', '早安', '午安', '晚安'])) {
      return _greeting(snapshot);
    }
    if (_matchAny(normalized, ['全部', '所有', '功能', '導覽', '教學', '地圖'])) {
      return _fullGuide(snapshot);
    }
    if (_matchAny(normalized, ['個人', '資料', '帳號', '登出', '頭像'])) {
      return _profileGuide();
    }
    if (_matchAny(normalized, ['首頁', '主畫面', '主頁'])) {
      return _homeGuide(snapshot);
    }
    if (_matchAny(normalized, ['交通', '公車', '接駁', '巴士'])) {
      return _transportGuide();
    }
    if (_matchAny(normalized, ['學習', '課程', '講座', '報名'])) {
      return _learningGuide();
    }
    if (_matchAny(normalized, ['活動', '共餐', '聚會'])) {
      return _eventsGuide();
    }
    if (_matchAny(normalized, ['藥單', '處方', '志工', '掃描', 'ocr', '健康', '藥'])) {
      if (_matchAny(normalized, ['怎麼', '如何', '哪裡', '哪', '在哪'])) {
        return _howHealthScan();
      }
      return _prescriptionReply(snapshot);
    }
    if (_matchAny(normalized, ['代購', '柑仔店', '訂單', '需求單', '商店', '買'])) {
      if (_matchAny(normalized, ['怎麼', '如何', '哪裡', '哪', '在哪'])) {
        return _howShop();
      }
      return _shopOrdersReply(snapshot);
    }
    if (_matchAny(normalized, ['吃藥', '提醒', '打卡', '鬧鐘'])) {
      return _medicationReply(snapshot);
    }
    if (_matchAny(normalized, ['可以做', '能做', '幫我', '幫忙'])) {
      return _appOverview(snapshot);
    }

    return _fallback(snapshot);
  }

  bool _matchAny(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  AssistantReply _greeting(AssistantSnapshot s) {
    return AssistantReply(
      text: '${_who(s)}您好！我是明德小幫手。\n\n'
          '${_prescriptionText(s, brief: true)}\n'
          '${_shopOrdersText(s, brief: true)}\n\n'
          '需要帶路請點下方按鈕，或問「全部功能」。',
      actions: const [_navHome, _navShop, _navHealthTab],
    );
  }

  AssistantReply _fullGuide(AssistantSnapshot s) {
    return AssistantReply(
      text: '明德 e 達人底部有六個分頁：\n'
          '首頁、柑仔店、交通、健康、學習、活動。\n\n'
          '另外可從右上角頭像進入個人資料。\n\n'
          '${_prescriptionText(s, brief: true)}\n'
          '${_shopOrdersText(s, brief: true)}',
      actions: const [
        _navHome,
        _navShop,
        _navTransport,
        _navHealthTab,
        _navLearning,
        _navEvents,
        _navProfile,
      ],
    );
  }

  AssistantReply _homeGuide(AssistantSnapshot s) {
    return AssistantReply(
      text: '首頁會顯示問候、藥單進度與常用功能。\n'
          '底部最左邊「首頁」圖示可隨時回到這裡。\n\n'
          '${_prescriptionText(s, brief: true)}',
      actions: const [_navHome],
    );
  }

  AssistantReply _transportGuide() {
    return AssistantReply(
      text: '交通分頁：查公車與接駁資訊。\n'
          '請點底部「交通」圖示（巴士）。\n\n'
          '※ 部分交通查詢功能仍在建置中，畫面可能顯示開發中內容。',
      actions: const [_navTransport],
    );
  }

  AssistantReply _learningGuide() {
    return AssistantReply(
      text: '學習分頁：社區課程、講座與報名。\n'
          '請點底部「學習」圖示（書本）。\n\n'
          '※ 部分課程列表仍在建置中。',
      actions: const [_navLearning],
    );
  }

  AssistantReply _eventsGuide() {
    return AssistantReply(
      text: '活動分頁：社區活動與共餐資訊。\n'
          '請點底部「活動」圖示（日曆）。\n\n'
          '※ 部分活動內容仍在建置中。',
      actions: const [_navEvents],
    );
  }

  AssistantReply _profileGuide() {
    return AssistantReply(
      text: '個人資料在首頁右上角圓形頭像。\n'
          '點開後可查看或編輯姓名、電話，也可登出。',
      actions: const [_navProfile, _navHome],
    );
  }

  AssistantReply _howHealthScan() {
    return AssistantReply(
      text: '健康掃描步驟：\n'
          '1. 底部點「健康」\n'
          '2. 使用掃描功能拍攝藥單\n'
          '3. 確認後「傳給志工幫忙」\n\n'
          '送出後首頁會顯示進度；志工確認後會排吃藥提醒。',
      actions: const [_navHealthTab, _navHealthScan],
    );
  }

  AssistantReply _howShop() {
    return AssistantReply(
      text: '柑仔店代購步驟：\n'
          '1. 底部點「柑仔店」或下方按鈕\n'
          '2. 選商品或手動填寫\n'
          '3. 確認後送出需求單\n\n'
          '可隨時問我「代購到哪了」查狀態。',
      actions: const [_navShop, _navShopOrders],
    );
  }

  AssistantReply _prescriptionReply(AssistantSnapshot s) {
    return AssistantReply(
      text: _prescriptionText(s),
      actions: const [_navHealthTab, _navHealthScan, _navHome],
    );
  }

  AssistantReply _shopOrdersReply(AssistantSnapshot s) {
    return AssistantReply(
      text: _shopOrdersText(s),
      actions: const [_navShopOrders, _navShop],
    );
  }

  AssistantReply _medicationReply(AssistantSnapshot s) {
    final task = s.latestPrescription;
    String text;
    if (task?.status == VolunteerTaskStatus.active) {
      text = '志工已確認藥單，系統會依時間提醒您吃藥。\n'
          '收到通知後點進去即可打卡。\n\n'
          '若沒收到提醒，請確認手機已允許 App 通知。';
    } else if (task != null &&
        (task.status == VolunteerTaskStatus.pending ||
            task.status == VolunteerTaskStatus.inProgress)) {
      text = '藥單還在「${task.status.label}」，確認後才會開始提醒。\n'
          '${_prescriptionText(s, brief: true)}';
    } else {
      text = '吃藥提醒會在志工確認藥單後自動安排。\n'
          '請先完成健康掃描並傳給志工。';
    }
    return AssistantReply(
      text: text,
      actions: const [_navHealthTab, _navHome],
    );
  }

  AssistantReply _appOverview(AssistantSnapshot s) {
    return AssistantReply(
      text: '我可以帶您到各分頁，並查詢藥單、代購狀態：\n'
          '• 柑仔店代購\n'
          '• 健康掃描與志工協助\n'
          '• 交通、學習、活動\n'
          '• 個人資料\n\n'
          '${_prescriptionText(s, brief: true)}\n'
          '${_shopOrdersText(s, brief: true)}',
      actions: const [
        _navShop,
        _navHealthTab,
        _navTransport,
        _navProfile,
      ],
    );
  }

  AssistantReply _fallback(AssistantSnapshot s) {
    return AssistantReply(
      text: '帶路、查藥單代購我都可以幫您。\n'
          '例如：「全部功能」「交通在哪」「我的藥單怎麼了」。\n\n'
          '${_prescriptionText(s, brief: true)}\n'
          '${_shopOrdersText(s, brief: true)}',
      actions: const [_navHome, _navShop, _navHealthTab, _navProfile],
    );
  }

  String _who(AssistantSnapshot s) {
    final name = (s.displayName ?? '').trim();
    return name.isNotEmpty ? '$name，' : '';
  }

  String _prescriptionText(AssistantSnapshot s, {bool brief = false}) {
    final task = s.latestPrescription;
    if (task == null) {
      return brief
          ? '藥單：尚無紀錄。'
          : '您目前沒有藥單紀錄。\n'
              '請用健康掃描拍照後傳給志工協助。';
    }

    final when = _formatTime(task.createdAt);
    final hospital = (task.hospitalName ?? '').trim();
    final hospitalLine =
        hospital.isNotEmpty && !brief ? '\n醫院：$hospital' : '';

    final detail = switch (task.status) {
      VolunteerTaskStatus.pending => '已送出，志工尚未接手。',
      VolunteerTaskStatus.inProgress => '志工處理中，可能會電話聯絡您。',
      VolunteerTaskStatus.active => '已確認！首頁可看提醒，請依時吃藥打卡。',
      VolunteerTaskStatus.done => '此筆已結案。',
      VolunteerTaskStatus.cancelled => '此筆已取消。',
    };

    if (brief) return '藥單（$when）：${task.status.label}。';
    return '最新藥單（$when）\n'
        '狀態：${task.status.label} — $detail$hospitalLine';
  }

  String _shopOrdersText(AssistantSnapshot s, {bool brief = false}) {
    final orders = s.recentOrders;
    if (orders.isEmpty) {
      return brief
          ? '代購：尚無需求單。'
          : '尚無柑仔店代購紀錄，請到柑仔店選商品後送出。';
    }

    final latest = orders.first;
    final when = _formatTime(latest.createdAt);
    final status = _orderStatusLabel(latest.status);
    final items = _summarizeItems(latest);

    if (brief) return '代購（$when）：$status。';

    final buffer = StringBuffer('最近代購（$when）\n狀態：$status');
    if (items.isNotEmpty) buffer.writeln('\n品項：$items');
    final lastEvent = latest.deliveryEvents.isNotEmpty
        ? latest.deliveryEvents.last
        : null;
    if (lastEvent != null) {
      buffer.writeln(
        '\n配送：${ShopOrderStatus.eventTypeLabel(lastEvent.eventType)}',
      );
      if (lastEvent.note != null && lastEvent.note!.trim().isNotEmpty) {
        buffer.writeln('（${lastEvent.note}）');
      }
    }
    buffer.writeln('\n（資料來自系統，非猜測）');
    if (s.loadedAt != null) {
      buffer.writeln('（更新：${_formatDateTime(s.loadedAt!)}）');
    }
    if (orders.length > 1) {
      buffer.writeln('共有 ${orders.length} 筆近期紀錄。');
    }
    return buffer.toString();
  }

  static String _orderStatusLabel(String status) {
    return switch (status) {
      'pending' => '已送出（待處理）',
      'processing' => '志工處理中',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  static String _summarizeItems(ShopOrderListRow order) {
    if (order.items.isEmpty) return '';
    final parts = order.items.take(3).map((e) {
      final name = e.productName.trim();
      return name.isEmpty ? '商品×${e.quantity}' : '$name×${e.quantity}';
    });
    final tail = order.items.length > 3 ? ' 等' : '';
    return '${parts.join('、')}$tail';
  }

  static String _formatTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)}';
  }

  static String _formatDateTime(DateTime t) {
    final l = t.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${l.year}/${p2(l.month)}/${p2(l.day)} ${p2(l.hour)}:${p2(l.minute)}';
  }
}

final assistantReplyServiceProvider = Provider<AssistantReplyService>(
  (ref) => const AssistantReplyService(),
);
