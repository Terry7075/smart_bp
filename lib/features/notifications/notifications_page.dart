import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: notifications.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('目前沒有通知'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(item.isRead ? Icons.notifications_none : Icons.notifications_active),
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.message}\n${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt.toLocal())}',
                      ),
                      isThreeLine: true,
                      trailing: item.isRead
                          ? null
                          : TextButton(
                              onPressed: () => ref
                                  .read(notificationServiceProvider)
                                  .markAsRead(item.id),
                              child: const Text('標示已讀'),
                            ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀取失敗：$error')),
      ),
    );
  }
}
