import 'package:cloud_firestore/cloud_firestore.dart';

/// 💬 SUPPORT CHAT MODEL — 1:1 chat between user and admin
class SupportChatModel {
  final String id; // same as userId
  final String userId;
  final String userName;
  final String userEmail;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCountUser;
  final int unreadCountAdmin;
  final bool userOnline;
  final bool adminOnline;
  final DateTime createdAt;

  const SupportChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCountUser = 0,
    this.unreadCountAdmin = 0,
    this.userOnline = false,
    this.adminOnline = false,
    required this.createdAt,
  });

  factory SupportChatModel.fromJson(Map<String, dynamic> json, String docId) {
    return SupportChatModel(
      id: docId,
      userId: json['userId'] ?? docId,
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: (json['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCountUser: json['unreadCountUser'] ?? 0,
      unreadCountAdmin: json['unreadCountAdmin'] ?? 0,
      userOnline: json['userOnline'] ?? false,
      adminOnline: json['adminOnline'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'unreadCountUser': unreadCountUser,
      'unreadCountAdmin': unreadCountAdmin,
      'userOnline': userOnline,
      'adminOnline': adminOnline,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
