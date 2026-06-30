import 'package:cloud_firestore/cloud_firestore.dart';

/// 💬 SUPPORT MESSAGE MODEL — Individual message in support chat
class SupportMessageModel {
  final String id;
  final String senderId;
  final String senderRole; // 'user' or 'admin'
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  const SupportMessageModel({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    this.readAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return SupportMessageModel(
      id: docId,
      senderId: json['senderId'] ?? '',
      senderRole: json['senderRole'] ?? 'user',
      body: json['body'] ?? '',
      imageUrl: json['imageUrl'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (json['readAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'body': body,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  bool get isImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isRead => readAt != null;
  bool get isFromUser => senderRole == 'user';
  bool get isFromAdmin => senderRole == 'admin';
}
