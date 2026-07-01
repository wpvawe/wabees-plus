import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_status.dart';
import 'message_type.dart';
import 'message_direction.dart';

/// 📨 MESSAGE MODEL
class MessageModel {
  final String id;
  final String contactPhone;   // WhatsApp phone: +923001234567
  final String contactName;    // Saved name or phone
  final MessageType type;
  final MessageDirection direction;
  final MessageStatus status;
  final String body;           // Text content
  final String? mediaUrl;      // For media messages
  final String? mediaId;       // WhatsApp media ID
  final String? mimeType;
  final String? caption;       // Media caption
  final String? fileName;      // Document file name
  final int? fileSize;         // File size in bytes
  final String? templateName;  // For template messages
  // Interactive meta
  final String? headerText;
  final String? footerText;
  final List<Map<String, dynamic>>? quickReplies; // [{id,title}]
  final Map<String, dynamic>? ctaButton; // {type,title,value}
  final String? whatsappMessageId; // Meta's message ID
  final String? errorReason;   // Why message failed
  final String? reactionEmoji; // Reaction emoji
  final String? reactionMsgId; // ID of msg being reacted to
  final DateTime? reactionAt;  // When reaction was set (newer-wins merge)
  // Reply context (Meta context.message_id echoed back on webhooks)
  final String? replyToId;     // Local Firestore doc id being replied to
  final String? replyToBody;   // Snapshot of quoted text/preview
  final String? replyToWamid;  // WhatsApp message id of quoted message
  final String? replyToType;   // Type of quoted message
  final String? botName;       // Bot that sent this message
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const MessageModel({
    required this.id,
    required this.contactPhone,
    required this.contactName,
    required this.type,
    required this.direction,
    required this.status,
    required this.body,
    this.mediaUrl,
    this.mediaId,
    this.mimeType,
    this.caption,
    this.fileName,
    this.fileSize,
    this.templateName,
    this.headerText,
    this.footerText,
    this.quickReplies,
    this.ctaButton,
    this.whatsappMessageId,
    this.errorReason,
    this.reactionEmoji,
    this.reactionMsgId,
    this.reactionAt,
    this.replyToId,
    this.replyToBody,
    this.replyToWamid,
    this.replyToType,
    this.botName,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
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

  factory MessageModel.fromJson(Map<String, dynamic> json, String docId) {
    return MessageModel(
      id: docId,
      contactPhone: json['contactPhone'] ?? '',
      contactName: json['contactName'] ?? json['contactPhone'] ?? '',
      type: MessageType.fromString(json['type'] ?? 'text'),
      direction: MessageDirection.fromString(json['direction'] ?? 'outgoing'),
      status: MessageStatus.fromString(json['status'] ?? 'pending'),
      body: json['body'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaId: json['mediaId'],
      mimeType: json['mimeType'],
      caption: json['caption'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      templateName: json['templateName'],
      headerText: json['headerText'],
      footerText: json['footerText'],
      quickReplies: (json['quickReplies'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      ctaButton: json['ctaButton'] != null
          ? Map<String, dynamic>.from(json['ctaButton'] as Map)
          : null,
      whatsappMessageId: json['whatsappMessageId'],
      errorReason: json['errorReason'],
      reactionEmoji: json['reactionEmoji'],
      reactionMsgId: json['reactionMsgId'],
      reactionAt: _parseDateNullable(json['reactionAt']),
      replyToId: json['replyToId'],
      replyToBody: json['replyToBody'],
      replyToWamid: json['replyToWamid'],
      replyToType: json['replyToType'],
      botName: json['botName'],
      createdAt: _parseDate(json['createdAt']),
      deliveredAt: _parseDateNullable(json['deliveredAt']),
      readAt: _parseDateNullable(json['readAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contactPhone': contactPhone,
      'contactName': contactName,
      'type': type.name,
      'direction': direction.name,
      'status': status.name,
      'body': body,
      'mediaUrl': mediaUrl,
      'mediaId': mediaId,
      'mimeType': mimeType,
      'caption': caption,
      'fileName': fileName,
      'fileSize': fileSize,
      'templateName': templateName,
      'headerText': headerText,
      'footerText': footerText,
      'quickReplies': quickReplies,
      'ctaButton': ctaButton,
      'whatsappMessageId': whatsappMessageId,
      'errorReason': errorReason,
      'reactionEmoji': reactionEmoji,
      'reactionMsgId': reactionMsgId,
      'reactionAt': reactionAt != null ? Timestamp.fromDate(reactionAt!) : null,
      'replyToId': replyToId,
      'replyToBody': replyToBody,
      'replyToWamid': replyToWamid,
      'replyToType': replyToType,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  MessageModel copyWith({
    String? id,
    String? contactPhone,
    String? contactName,
    MessageType? type,
    MessageDirection? direction,
    MessageStatus? status,
    String? body,
    String? mediaUrl,
    String? mediaId,
    String? mimeType,
    String? caption,
    String? fileName,
    int? fileSize,
    String? templateName,
    String? headerText,
    String? footerText,
    List<Map<String, dynamic>>? quickReplies,
    Map<String, dynamic>? ctaButton,
    String? whatsappMessageId,
    String? errorReason,
    String? reactionEmoji,
    String? reactionMsgId,
    DateTime? reactionAt,
    String? replyToId,
    String? replyToBody,
    String? replyToWamid,
    String? replyToType,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      contactPhone: contactPhone ?? this.contactPhone,
      contactName: contactName ?? this.contactName,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      body: body ?? this.body,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaId: mediaId ?? this.mediaId,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      templateName: templateName ?? this.templateName,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      quickReplies: quickReplies ?? this.quickReplies,
      ctaButton: ctaButton ?? this.ctaButton,
      whatsappMessageId: whatsappMessageId ?? this.whatsappMessageId,
      errorReason: errorReason ?? this.errorReason,
      reactionEmoji: reactionEmoji ?? this.reactionEmoji,
      reactionMsgId: reactionMsgId ?? this.reactionMsgId,
      reactionAt: reactionAt ?? this.reactionAt,
      replyToId: replyToId ?? this.replyToId,
      replyToBody: replyToBody ?? this.replyToBody,
      replyToWamid: replyToWamid ?? this.replyToWamid,
      replyToType: replyToType ?? this.replyToType,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Preview text for inbox list
  String get preview {
    switch (type) {
      case MessageType.text:
        return body;
      case MessageType.image:
        return '📷 ${caption ?? 'Photo'}';
      case MessageType.video:
        return '🎥 ${caption ?? 'Video'}';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.document:
        return '📄 ${caption ?? 'Document'}';
      case MessageType.template:
        return '📋 Template: ${templateName ?? 'message'}';
      case MessageType.interactive:
        return '🔘 Interactive';
      case MessageType.location:
        return '📍 Location';
      case MessageType.contact:
        return '👤 Contact';
      case MessageType.sticker:
        return '🏷️ Sticker';
      case MessageType.reaction:
        return reactionEmoji ?? '❤️';
      case MessageType.button:
        return '🔘 $body';
      case MessageType.order:
        return '🛒 Order';
      case MessageType.system:
        return '⚙️ $body';
      case MessageType.unsupported:
        return body;
    }
  }
}
