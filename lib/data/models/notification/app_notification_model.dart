import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔔 APP NOTIFICATION MODEL — In-app notifications for user and admin
class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // plan_activated, plan_rejected, new_support_message, system
  final Map<String, dynamic> data; // extra data (planId, chatId, etc.)
  final bool read;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.read = false,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json, String docId) {
    return AppNotificationModel(
      id: docId,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'system',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      read: json['read'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Icon based on type
  String get iconName {
    switch (type) {
      case 'plan_activated':
        return '✅';
      case 'plan_rejected':
        return '❌';
      case 'plan_request': // Added this case for Admin
        return '💎';
      case 'user_approved':
        return '🎉';
      case 'campaign_completed':
        return '🚀';
      case 'new_message':
        return '💬';
      case 'bot_triggered':
        return '🤖';
      case 'template_approved':
        return '📝';
      case 'template_rejected':
        return '📝';
      case 'new_support_message':
        return '💬';
      default:
        return '🔔';
    }
  }
}
