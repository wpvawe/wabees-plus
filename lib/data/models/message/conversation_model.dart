import 'package:cloud_firestore/cloud_firestore.dart';

/// 📇 CONVERSATION MODEL (for inbox list)
class ConversationModel {
  final String contactPhone;
  final String contactName;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageAt;
  final int unreadCount;
  final String? profileImageUrl;
  final DateTime? lastIncomingMessageAt;
  final List<String> tags;
  final bool isPinned;
  final int pinOrder;
  final String? activeChatterId;
  final String? activeChatterEmail;
  final bool isBlocked;

  const ConversationModel({
    required this.contactPhone,
    required this.contactName,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.unreadCount,
    this.profileImageUrl,
    this.lastIncomingMessageAt,
    this.tags = const [],
    this.isPinned = false,
    this.pinOrder = 0,
    this.activeChatterId,
    this.activeChatterEmail,
    this.isBlocked = false,
  });

  /// Parse a date field that may be a Firestore Timestamp or an ISO string
  static DateTime _parseDate(dynamic value, [DateTime? fallback]) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json, String docId) {
    return ConversationModel(
      contactPhone: docId,
      contactName: json['contactName'] ?? docId,
      lastMessage: json['lastMessage'] ?? '',
      lastMessageType: json['lastMessageType'] ?? 'text',
      lastMessageAt: _parseDate(json['lastMessageAt']),
      unreadCount: json['unreadCount'] ?? 0,
      profileImageUrl: json['profileImageUrl'],
      lastIncomingMessageAt: _parseDateNullable(json['lastIncomingMessageAt']),
      tags: List<String>.from(json['tags'] ?? []),
      isPinned: json['isPinned'] ?? false,
      pinOrder: json['pinOrder'] ?? 0,
      activeChatterId: json['activeChatterId'],
      activeChatterEmail: json['activeChatterEmail'],
      isBlocked: json['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contactName': contactName,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'unreadCount': unreadCount,
      'profileImageUrl': profileImageUrl,
      if (lastIncomingMessageAt != null)
        'lastIncomingMessageAt': Timestamp.fromDate(lastIncomingMessageAt!),
      'tags': tags,
      'isPinned': isPinned,
      'pinOrder': pinOrder,
      'isBlocked': isBlocked,
    };
  }

  /// Whether the 24h customer service window is still open.
  /// WhatsApp allows free-form replies for 24 hours after the customer's last incoming message.
  bool get isReplyWindowOpen {
    if (lastIncomingMessageAt == null) return false;
    return DateTime.now().difference(lastIncomingMessageAt!).inHours < 24;
  }

  /// Time remaining in the 24h reply window.
  /// Returns null if window is closed or no incoming message.
  Duration? get replyWindowRemaining {
    if (lastIncomingMessageAt == null) return null;
    final deadline = lastIncomingMessageAt!.add(const Duration(hours: 24));
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return null;
    return remaining;
  }

  /// Formatted string for reply window remaining time (e.g. "5h 30m", "23h 15m").
  String? get replyWindowRemainingText {
    final remaining = replyWindowRemaining;
    if (remaining == null) return null;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
