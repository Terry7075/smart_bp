import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Stream<List<AppNotification>> watchMyNotifications() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => AppNotification.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }
}
