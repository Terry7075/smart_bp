import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 呼叫 Edge `send_shop_push`（僅 Android token；iOS 靠 Realtime）。
class ShopPushInvoker {
  ShopPushInvoker._();
  static final ShopPushInvoker instance = ShopPushInvoker._();

  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send_shop_push',
        body: body,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPushInvoker: $e');
      }
    }
  }

  /// 志工：新代購需求等。
  Future<void> notifyVolunteers({
    required String eventType,
    String? elderUserId,
    String title = '明德 e 達人',
    String? bodyText,
    Map<String, dynamic>? payload,
  }) async {
    await _invoke({
      'target_role': 'volunteer',
      'user_id': ?elderUserId,
      'event_type': eventType,
      'title': title,
      'body_text': bodyText ?? '有新的代購需求',
      'payload': {
        'route': '/volunteer/shop-orders',
        ...?payload,
      },
      'platform': 'android',
    });
  }

  /// 長輩訂單狀態／備註更新（可選一併通知綁定家屬）。
  Future<void> notifyElderAndFamily({
    required String elderUserId,
    required String orderId,
    required String eventType,
    required String title,
    String? bodyText,
    bool notifyFamily = true,
  }) async {
    await _invoke({
      'elder_user_id': elderUserId,
      'notify_family': notifyFamily,
      'event_type': eventType,
      'title': title,
      'body_text': bodyText ?? '您的代購訂單有更新',
      'payload': {
        'order_id': orderId,
        'route': '/shop/orders/$orderId',
        'family_route': '/family/home',
      },
      'platform': 'android',
    });
  }
}
