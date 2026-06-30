import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification/app_notification_model.dart';
import '../../../providers/notification/notification_provider.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../core/services/notification_service.dart';

/// 🔔 NOTIFICATIONS SCREEN — Shows all in-app notifications
class NotificationsScreen extends ConsumerStatefulWidget {
  final bool isAdmin;

  const NotificationsScreen({super.key, this.isAdmin = false});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {

  @override
  void initState() {
    super.initState();
    // NOTE: Do NOT auto-mark-all-read here.
    // Notifications are only marked read when:
    //   1. User taps a specific notification (marks that one read)
    //   2. User explicitly presses the "Mark all read" button
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = widget.isAdmin
        ? ref.watch(adminNotificationsProvider)
        : ref.watch(userNotificationsProvider);
    final user = ref.watch(currentUserProvider);
    // Agents read owner's notifications — use ownerId for all operations
    final ownerId = user?.dataOwner ?? user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(notificationRepositoryProvider);
              try {
                if (widget.isAdmin) {
                  await repo.markAllAdminRead();
                } else if (ownerId != null) {
                  await repo.markAllRead(ownerId);
                }
              } catch (e) {
                debugPrint('🔔 markAllRead error: $e');
              }
              // Clear all local (OS tray) notifications
              NotificationService.instance.cancelAll();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (ctx, i) {
              final n = notifications[i];
              return _NotificationTile(
                notification: n,
                isAdmin: widget.isAdmin,
                onTap: () async {
                  // Mark as read (use ownerId for agents)
                  if (n.read) return; // Already read — skip redundant write
                  final repo = ref.read(notificationRepositoryProvider);
                  try {
                    if (widget.isAdmin) {
                      await repo.markAdminAsRead(n.id);
                    } else if (ownerId != null) {
                      await repo.markAsRead(ownerId, n.id);
                    }
                  } catch (e) {
                    debugPrint('🔔 markAsRead error: $e');
                  }
                },
                onDismiss: () async {
                  final repo = ref.read(notificationRepositoryProvider);
                  try {
                    if (widget.isAdmin) {
                      await repo.deleteAdminNotification(n.id);
                    } else if (ownerId != null) {
                      await repo.deleteNotification(ownerId, n.id);
                    }
                  } catch (e) {
                    debugPrint('🔔 deleteNotification error: $e');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.isAdmin,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.read
              ? theme.colorScheme.surfaceContainerHighest
              : AppColors.primary.withAlpha(20),
          child: Text(
            notification.iconName,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: notification.read
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
