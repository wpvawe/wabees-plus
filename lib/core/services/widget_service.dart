import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/models/message/conversation_model.dart';

/// 📱 HOME SCREEN WIDGET DATA SYNC
/// Pushes latest conversations to Android home screen widget via SharedPreferences.
class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  /// Update widget with latest conversations
  Future<void> syncConversations(List<ConversationModel> conversations) async {
    try {
      // Take top 8 most recent conversations
      final sorted = List<ConversationModel>.from(conversations)
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      final top = sorted.take(8).toList();

      final items = top.map((c) => {
        'name': c.contactName,
        'message': c.lastMessage.length > 60
            ? '${c.lastMessage.substring(0, 60)}...'
            : c.lastMessage,
        'time': _formatTime(c.lastMessageAt),
        'phone': c.contactPhone,
        'unread': c.unreadCount,
      }).toList();

      await HomeWidget.saveWidgetData<String>(
        'widget_conversations',
        jsonEncode(items),
      );

      // Update time
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
      await HomeWidget.saveWidgetData<String>('widget_update_time', timeStr);

      // Trigger widget refresh
      await HomeWidget.updateWidget(
        name: 'ConversationsWidgetProvider',
        androidName: 'ConversationsWidgetProvider',
        qualifiedAndroidName: 'com.wabees.wabees_android.ConversationsWidgetProvider',
      );

      debugPrint('📱 Widget: synced ${items.length} conversations');
    } catch (e) {
      debugPrint('📱 Widget sync error: $e');
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
