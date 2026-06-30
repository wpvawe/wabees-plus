import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message/conversation_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/phone_utils.dart';
import '../messaging/messaging_provider.dart';
import '../auth/auth_provider.dart';
import '../../core/services/widget_service.dart';

/// 🔔 NOTIFICATION LISTENER PROVIDER
/// Watches conversations stream and fires local notifications for new unread messages.

final notificationListenerProvider = Provider<void>((ref) {
  ref.keepAlive();

  final userId = ref.watch(userIdProvider);
  debugPrint('🔔 NotifListener: ACTIVATED for user=$userId');

  final Map<String, DateTime> lastIncomingAt = {};
  final Map<String, int> lastUnreadCount = {};
  bool isFirstLoad = true;
  // Grace period: skip notifications for first 5 seconds after app start
  // This prevents duplicates when app opens after background FCM notification
  DateTime? startupTime;

  ref.listen<AsyncValue<List<ConversationModel>>>(
    conversationsProvider,
    (previous, next) {
      next.whenData((conversations) {
        if (isFirstLoad) {
          isFirstLoad = false;
          startupTime = DateTime.now();
          for (final conv in conversations) {
            final key = PhoneUtils.normalize(conv.contactPhone);
            lastIncomingAt[key] = conv.lastIncomingMessageAt ?? conv.lastMessageAt;
            lastUnreadCount[key] = conv.unreadCount;
          }
          debugPrint('🔔 NotifListener: first load done, tracked ${lastIncomingAt.length} conversations');
          // Sync to home screen widget
          WidgetService.instance.syncConversations(conversations);
          return;
        }

        // Skip notifications during 5-second startup grace period
        if (startupTime != null && DateTime.now().difference(startupTime!).inSeconds < 5) {
          // Still update tracking maps silently
          for (final conv in conversations) {
            final key = PhoneUtils.normalize(conv.contactPhone);
            lastIncomingAt[key] = conv.lastIncomingMessageAt ?? conv.lastMessageAt;
            lastUnreadCount[key] = conv.unreadCount;
          }
          WidgetService.instance.syncConversations(conversations);
          return;
        }
        startupTime = null; // Grace period over

        for (final conv in conversations) {
          final key = PhoneUtils.normalize(conv.contactPhone);
          final prevIncoming = lastIncomingAt[key];
          final prevUnread = lastUnreadCount[key] ?? 0;
          final lastIncoming = conv.lastIncomingMessageAt ?? conv.lastMessageAt;

          // Bug 2 fix: skip notifications from blocked contacts entirely
          if (conv.isBlocked) {
            // Also cancel any previously-shown notification from this contact
            try {
              NotificationService.instance.cancel(key.hashCode, tag: key);
            } catch (_) {}
            lastIncomingAt[key] = lastIncoming;
            lastUnreadCount[key] = conv.unreadCount;
            continue;
          }

          // Auto-cancel notification when conversation is read
          if (conv.unreadCount == 0) {
            try {
              NotificationService.instance.cancel(key.hashCode, tag: key);
            } catch (_) {}
          }

          // Detect new incoming message:
          final timestampChanged = prevIncoming == null || lastIncoming.isAfter(prevIncoming);
          final unreadIncreased = conv.unreadCount > prevUnread;
          final hasNewIncoming = conv.unreadCount > 0 && (timestampChanged || unreadIncreased);

          if (hasNewIncoming) {
            // Check if message notifications are enabled in settings
            if (!NotificationService.instance.messagesEnabled) continue;
            debugPrint('🔔 FIRING NOTIFICATION for ${conv.contactName}');
            try {
              NotificationService.instance.showNotification(
                id: key.hashCode,
                tag: key,
                title: conv.contactName,
                body: conv.lastMessage.isNotEmpty
                    ? conv.lastMessage
                    : 'New message',
                payload: 'message:${conv.contactPhone}',
                channelId: 'wabees_messages_v2',
                channelName: 'Messages',
              );
            } catch (e) {
              debugPrint('🔔 Notification error: $e');
            }
          }

          lastIncomingAt[key] = lastIncoming;
          lastUnreadCount[key] = conv.unreadCount;
        }

        // Sync to home screen widget on every update
        WidgetService.instance.syncConversations(conversations);
      });
    },
  );
});
