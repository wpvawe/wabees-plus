import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/message/message_model.dart';
import '../models/message/message_type.dart';
import '../models/message/message_status.dart';
import '../models/message/message_direction.dart';
import '../models/message/conversation_model.dart';
import '../../core/utils/phone_utils.dart';
import 'whatsapp_repository.dart';
import '../models/whatsapp/whatsapp_api_response.dart';
import 'plan_repository.dart';

/// 📨 MESSAGE REPOSITORY
class MessageRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final WhatsappRepository _whatsappRepo = WhatsappRepository();
  final PlanRepository _planRepo = PlanRepository();

  // ============ CONVERSATIONS (REALTIME) ============
  /// Groups conversations by normalized phone to avoid duplicate nodes
  Stream<List<ConversationModel>> getConversations(String userId) {
    return _firestore.user(userId)
        .collection('conversations')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) {
      final Map<String, ConversationModel> grouped = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final conv = ConversationModel.fromJson(data, doc.id);
        final key = PhoneUtils.normalize(conv.contactPhone);
        final existing = grouped[key];

        if (existing == null) {
          grouped[key] = ConversationModel(
            contactPhone: key,
            contactName: conv.contactName,
            lastMessage: conv.lastMessage,
            lastMessageType: conv.lastMessageType,
            lastMessageAt: conv.lastMessageAt,
            unreadCount: conv.unreadCount,
            profileImageUrl: conv.profileImageUrl,
            lastIncomingMessageAt: conv.lastIncomingMessageAt,
            tags: conv.tags,
            isPinned: conv.isPinned,
            pinOrder: conv.pinOrder,
            isBlocked: conv.isBlocked,
          );
        } else {
          final isNewer = conv.lastMessageAt.isAfter(existing.lastMessageAt);
          final merged = ConversationModel(
            contactPhone: key,
            contactName: existing.contactName.length >= conv.contactName.length
                ? existing.contactName
                : conv.contactName,
            lastMessage: isNewer ? conv.lastMessage : existing.lastMessage,
            lastMessageType:
                isNewer ? conv.lastMessageType : existing.lastMessageType,
            lastMessageAt: isNewer ? conv.lastMessageAt : existing.lastMessageAt,
            unreadCount: existing.unreadCount + conv.unreadCount,
            profileImageUrl: existing.profileImageUrl ?? conv.profileImageUrl,
            lastIncomingMessageAt:
                conv.lastIncomingMessageAt ?? existing.lastIncomingMessageAt,
            tags: existing.tags.isNotEmpty ? existing.tags : conv.tags,
            isPinned: existing.isPinned || conv.isPinned,
            pinOrder: existing.pinOrder > 0 ? existing.pinOrder : conv.pinOrder,
            isBlocked: existing.isBlocked || conv.isBlocked,
          );
          grouped[key] = merged;
        }
      }

      final list = grouped.values.toList()
        ..sort((a, b) {
          // Pinned first, then by lastMessageAt
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          if (a.isPinned && b.isPinned) return b.pinOrder.compareTo(a.pinOrder);
          return b.lastMessageAt.compareTo(a.lastMessageAt);
        });
      return list;
    });
  }

  // ============ SINGLE CONVERSATION (REALTIME) ============
  Stream<ConversationModel?> getConversationStream(String userId, String contactPhone) {
    final phone = PhoneUtils.normalize(contactPhone);
    return _firestore.user(userId)
        .collection('conversations')
        .doc(phone)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ConversationModel.fromJson(doc.data()!, doc.id);
    });
  }

  // ============ MESSAGES FOR CONTACT (REALTIME) ============
  Stream<List<MessageModel>> getMessages(String userId, String contactPhone) {
    final phone = PhoneUtils.normalize(contactPhone);
    return _firestore.user(userId)
        .collection('messages')
        .where('contactPhone', isEqualTo: phone)
        .snapshots()
        .map((snap) {
          final msgs = snap.docs
              .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          if (msgs.length > 200) return msgs.sublist(msgs.length - 200);
          return msgs;
        });
  }

  // ============ SENT MESSAGE COUNT (24h) — for messaging limit usage ============
  Future<int> getSentMessageCount24h(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final snap = await _firestore.user(userId)
        .collection('messages')
        .where('direction', isEqualTo: 'outgoing')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .get();
    return snap.docs.length;
  }

  // ============ SENT MESSAGE COUNT (date range) — for monthly insights ============
  Future<Map<String, int>> getMessageCountByRange(String userId, DateTime start, DateTime end) async {
    // Simple single-field queries (auto-indexed, no composite index needed)
    final outCount = await _firestore.user(userId)
        .collection('messages')
        .where('direction', isEqualTo: 'outgoing')
        .count()
        .get();
    final inCount = await _firestore.user(userId)
        .collection('messages')
        .where('direction', isEqualTo: 'incoming')
        .count()
        .get();
    return {
      'sent': outCount.count ?? 0,
      'received': inCount.count ?? 0,
    };
  }

  // ============ SEND TEXT MESSAGE ============
  Future<MessageModel?> sendTextMessage({
    required String userId,
    required String contactPhone,
    required String contactName,
    required String text,
    String? replyToId,
    String? replyToBody,
    String? replyToWamid,
    String? replyToType,
  }) async {
    // Normalize phone to prevent duplicate conversations
    final normalizedPhone = PhoneUtils.normalize(contactPhone);
    contactPhone = normalizedPhone;
    if (userId.isEmpty) {
      return MessageModel(
        id: '',
        contactPhone: contactPhone,
        contactName: contactName,
        type: MessageType.text,
        direction: MessageDirection.outgoing,
        status: MessageStatus.failed,
        body: text,
        errorReason: 'Not logged in. Please restart the app.',
        createdAt: DateTime.now(),
      );
    }

    // 24-hour reply window pre-check.
    // WhatsApp only allows free-form messages when the customer has messaged in the
    // last 24 hours. We first read conversations/{phone}.lastIncomingMessageAt, and
    // if that field is missing/stale we fall back to scanning the messages
    // subcollection for the most recent window-opening inbound message — this keeps
    // the pre-check in sync with the banner UI (which also derives from messages).
    final windowOpen = await _isReplyWindowOpen(userId, contactPhone);
    if (windowOpen == false) {
      return MessageModel(
        id: '',
        contactPhone: contactPhone,
        contactName: contactName,
        type: MessageType.text,
        direction: MessageDirection.outgoing,
        status: MessageStatus.failed,
        body: text,
        errorReason:
            'Cannot send free-form message: the 24-hour reply window is closed. '
            'Please use an approved Template Message to start this conversation.',
        createdAt: DateTime.now(),
      );
    }
    // windowOpen == null → indeterminate (Firestore error / permission). Do NOT block;
    // let WhatsApp be the source of truth and surface any 131047 error on failure.

    DocumentReference? msgRef;

    try {
      // 1. Create message in Firestore (pending)
      msgRef = _firestore.user(userId).collection('messages').doc();
      final message = MessageModel(
        id: msgRef.id,
        contactPhone: contactPhone,
        contactName: contactName,
        type: MessageType.text,
        direction: MessageDirection.outgoing,
        status: MessageStatus.pending,
        body: text,
        replyToId: replyToId,
        replyToBody: replyToBody,
        replyToWamid: replyToWamid,
        replyToType: replyToType,
        createdAt: DateTime.now(),
      );

      // Run message write + conversation update + counter in PARALLEL
      // This saves ~200-400ms vs sequential writes
      await Future.wait([
        msgRef.set(message.toJson()),
        _updateConversation(
          userId: userId,
          contactPhone: contactPhone,
          contactName: contactName,
          lastMessage: text,
          lastMessageType: 'text',
        ),
        _firestore.user(userId).update({
          'totalMessages': FieldValue.increment(1),
        }).catchError((_) => null), // Non-critical
      ]);

      // 2. Send via WhatsApp API (config is cached — no Firestore read)
      final result = await _whatsappRepo.sendText(
        userId: userId,
        to: contactPhone,
        message: text,
        contextMessageId: replyToWamid,
      );

      // 3. Update status
      if (result.success) {
        final waMessageId = result.data?['messages']?[0]?['id'];
        await msgRef.update({
          'status': MessageStatus.sent.name,
          'whatsappMessageId': waMessageId,
          'errorReason': null,
        });

        // Track plan usage (fire-and-forget — don't block UI)
        _planRepo.incrementMessages(userId).catchError((_) {});

        return message.copyWith(
          status: MessageStatus.sent,
          whatsappMessageId: waMessageId,
        );
      } else {
        // Extract error — handle both Map and String error formats
        String errorMsg = result.message ?? 'Failed to send';
        final rawError = result.data?['error'];
        if (rawError is Map) {
          errorMsg = rawError['message'] ?? errorMsg;
        } else if (rawError is String) {
          errorMsg = rawError;
        }
        // Self-heal: if Meta says the 24h window is actually closed, clear
        // lastIncomingMessageAt so the chat banner + next pre-check agree.
        if (_isWindowClosedError(errorMsg, rawError)) {
          _clearLastIncomingMessageTime(userId, contactPhone);
          errorMsg = 'The 24-hour reply window is closed. Please send an approved '
              'Template Message to re-engage this contact.';
        }
        await msgRef.update({
          'status': MessageStatus.failed.name,
          'errorReason': errorMsg,
        });
        return message.copyWith(status: MessageStatus.failed, errorReason: errorMsg);
      }
    } catch (e) {
      // Catch-all: if anything throws, mark as failed with actual error
      final errorMsg = 'Send failed: ${e.toString()}';

      // Try to update the Firestore doc if it was created
      if (msgRef != null) {
        try {
          await msgRef.update({
            'status': MessageStatus.failed.name,
            'errorReason': errorMsg,
          });
        } catch (_) {
          // Can't even update — Firestore itself may be down
        }
      }

      return MessageModel(
        id: msgRef?.id ?? '',
        contactPhone: contactPhone,
        contactName: contactName,
        type: MessageType.text,
        direction: MessageDirection.outgoing,
        status: MessageStatus.failed,
        body: text,
        errorReason: errorMsg,
        createdAt: DateTime.now(),
      );
    }
  }

  // ============ RESEND FAILED MESSAGE ============
  Future<bool> resendMessage({
    required String userId,
    required String messageId,
  }) async {
    final docRef = _firestore.user(userId).collection('messages').doc(messageId);
    final doc = await docRef.get();
    if (!doc.exists) return false;

    final msg = MessageModel.fromJson(doc.data()!, doc.id);
    if (msg.status != MessageStatus.failed) return false;

    // Reset status to pending
    await docRef.update({
      'status': MessageStatus.pending.name,
      'errorReason': null,
    });

    // Determine if this is a media or text message
    final isMedia = msg.type == MessageType.image ||
        msg.type == MessageType.video ||
        msg.type == MessageType.audio ||
        msg.type == MessageType.document;

    WhatsappApiResponse result;

    if (isMedia && (msg.mediaUrl != null || msg.mediaId != null)) {
      // Re-send as media (not text!) — this prevents voice "🎤 Voice message" going as text
      final mediaTypeStr = msg.type == MessageType.image
          ? 'image'
          : msg.type == MessageType.video
              ? 'video'
              : msg.type == MessageType.audio
                  ? 'audio'
                  : 'document';
      result = await _whatsappRepo.sendMedia(
        userId: userId,
        to: msg.contactPhone,
        mediaType: mediaTypeStr,
        mediaUrl: msg.mediaUrl ?? '',
        mediaId: msg.mediaId,
        caption: msg.caption,
        isVoice: msg.type == MessageType.audio && (msg.fileName == 'Voice message' || msg.body.contains('Voice')),
      );
    } else {
      // Text message — send as text
      result = await _whatsappRepo.sendText(
        userId: userId,
        to: msg.contactPhone,
        message: msg.body,
      );
    }

    if (result.success) {
      final waMessageId = result.data?['messages']?[0]?['id'];
      await docRef.update({
        'status': MessageStatus.sent.name,
        'whatsappMessageId': waMessageId,
        'errorReason': null,
      });
      return true;
    } else {
      final errorMsg = result.data?['error']?['message'] ?? 'Failed to resend';
      await docRef.update({
        'status': MessageStatus.failed.name,
        'errorReason': errorMsg,
      });
      return false;
    }
  }

  // ============ SEND MEDIA MESSAGE ============
  Future<MessageModel?> sendMediaMessage({
    required String userId,
    required String contactPhone,
    required String contactName,
    required String mediaType, // image, video, audio, document
    required String mediaUrl,
    String? mediaId,
    String? caption,
    String? fileName,
    int? fileSize,
    bool isVoice = false, // true = real WhatsApp voice note
    String? replyToId,
    String? replyToBody,
    String? replyToWamid,
    String? replyToType,
  }) async {
    contactPhone = PhoneUtils.normalize(contactPhone);
    final msgRef = _firestore.user(userId).collection('messages').doc();
    final msgTypeMap = {
      'image': MessageType.image,
      'video': MessageType.video,
      'audio': MessageType.audio,
      'document': MessageType.document,
    };

    final message = MessageModel(
      id: msgRef.id,
      contactPhone: contactPhone,
      contactName: contactName,
      type: msgTypeMap[mediaType] ?? MessageType.document,
      direction: MessageDirection.outgoing,
      status: MessageStatus.pending,
      body: isVoice ? '' : (caption ?? '[$mediaType]'),
      mediaUrl: mediaUrl,
       mediaId: mediaId,
      caption: caption,
      fileName: fileName,
      fileSize: fileSize,
      replyToId: replyToId,
      replyToBody: replyToBody,
      replyToWamid: replyToWamid,
      replyToType: replyToType,
      createdAt: DateTime.now(),
    );

    await msgRef.set(message.toJson());

    await _firestore.user(userId).update({
      'totalMessages': FieldValue.increment(1),
    });

    await _updateConversation(
      userId: userId,
      contactPhone: contactPhone,
      contactName: contactName,
      lastMessage: message.preview,
      lastMessageType: mediaType,
    );

    final result = await _whatsappRepo.sendMedia(
      userId: userId,
      to: contactPhone,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaId: mediaId,
      caption: caption,
      isVoice: isVoice,
      filename: mediaType == 'document' ? fileName : null,
      contextMessageId: replyToWamid,
    );

    if (result.success) {
      final waMessageId = result.data?['messages']?[0]?['id'];
      await msgRef.update({
        'status': MessageStatus.sent.name,
        'whatsappMessageId': waMessageId,
      });
      return message.copyWith(status: MessageStatus.sent);
    } else {
      final errorMsg = result.data?['error']?['message'] ?? 'Failed to send media';
      await msgRef.update({
        'status': MessageStatus.failed.name,
        'errorReason': errorMsg,
      });
      return message.copyWith(status: MessageStatus.failed, errorReason: errorMsg);
    }
  }

  // ============ SEND TEMPLATE MESSAGE ============
  Future<MessageModel?> sendTemplateMessage({
    required String userId,
    required String contactPhone,
    required String contactName,
    required String templateName,
    required String languageCode,
    List<Map<String, dynamic>>? components,
  }) async {
    contactPhone = PhoneUtils.normalize(contactPhone);
    final msgRef = _firestore.user(userId).collection('messages').doc();
    final message = MessageModel(
      id: msgRef.id,
      contactPhone: contactPhone,
      contactName: contactName,
      type: MessageType.template,
      direction: MessageDirection.outgoing,
      status: MessageStatus.pending,
      body: 'Template: $templateName',
      templateName: templateName,
      createdAt: DateTime.now(),
    );

    await msgRef.set(message.toJson());

    await _updateConversation(
      userId: userId,
      contactPhone: contactPhone,
      contactName: contactName,
      lastMessage: '📋 Template: $templateName',
      lastMessageType: 'template',
    );

    final result = await _whatsappRepo.sendTemplate(
      userId: userId,
      to: contactPhone,
      templateName: templateName,
      languageCode: languageCode,
      components: components,
    );

    if (result.success) {
      final waMessageId = result.data?['messages']?[0]?['id'];
      await msgRef.update({
        'status': MessageStatus.sent.name,
        'whatsappMessageId': waMessageId,
      });
      return message.copyWith(status: MessageStatus.sent);
    } else {
      await msgRef.update({'status': MessageStatus.failed.name});
      return message.copyWith(status: MessageStatus.failed);
    }
  }

  // ============ HELPER: FIND ALL CONVERSATION DOCS FOR PHONE ============
  Future<List<DocumentReference>> _findAllConversationDocs(String userId, String contactPhone) async {
    final normalized = PhoneUtils.normalize(contactPhone);
    final convCol = _firestore.user(userId).collection('conversations');
    
    // Fetch all conversations to ensure we catch every variant (normalized, raw, weird formats)
    final snap = await convCol.get();
    
    final matchingDocs = <DocumentReference>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final docId = doc.id;
      final docPhone = data['contactPhone'] as String?;

      // Check if doc ID matches (normalized)
      if (PhoneUtils.normalize(docId) == normalized) {
        matchingDocs.add(doc.reference);
        continue;
      }
      
      // Check if 'contactPhone' field matches (normalized)
      if (docPhone != null && PhoneUtils.normalize(docPhone) == normalized) {
        matchingDocs.add(doc.reference);
      }
    }
    return matchingDocs;
  }

  // ============ MARK CONVERSATION READ ============
  Future<void> markConversationRead(String userId, String contactPhone) async {
    final docs = await _findAllConversationDocs(userId, contactPhone);
    for (final doc in docs) {
      try {
        await doc.set({'unreadCount': 0, 'isRead': true}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // ============ CONVERSATION LOCKING ============
  /// Lock a conversation so only this user can chat (owner/agent exclusion)
  Future<void> lockConversation(String ownerId, String contactPhone, String chatterId, String chatterEmail) async {
    try {
      final phone = PhoneUtils.normalize(contactPhone);
      await _firestore.user(ownerId).collection('conversations').doc(phone).set({
        'activeChatterId': chatterId,
        'activeChatterEmail': chatterEmail,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('lockConversation error: $e');
    }
  }

  /// Unlock a conversation (clear active chatter) — only if current user is the locker
  Future<void> unlockConversation(String ownerId, String contactPhone, String chatterId) async {
    try {
      final phone = PhoneUtils.normalize(contactPhone);
      final doc = _firestore.user(ownerId).collection('conversations').doc(phone);
      final snap = await doc.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        if (data['activeChatterId'] == chatterId) {
          await doc.update({
            'activeChatterId': FieldValue.delete(),
            'activeChatterEmail': FieldValue.delete(),
          });
        }
      }
    } catch (e) {
      debugPrint('unlockConversation error: $e');
    }
  }

  // ============ GET LATEST INCOMING MESSAGE ID (for read receipts) ============
  Future<String?> getLatestIncomingMessageId(String userId, String contactPhone) async {
    try {
      final phone = PhoneUtils.normalize(contactPhone);
      final snap = await _firestore.user(userId)
          .collection('messages')
          .where('contactPhone', isEqualTo: phone)
          .where('direction', isEqualTo: 'incoming')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data()['whatsappMessageId'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ============ DELETE MESSAGE ============
  Future<void> deleteMessage(String userId, String messageId) async {
    await _firestore.user(userId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ============ TOTAL UNREAD COUNT ============
  Stream<int> getTotalUnreadCount(String userId) {
    return _firestore.user(userId)
        .collection('conversations')
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['unreadCount'] as int?) ?? 0;
      }
      return total;
    });
  }

  // ============ UPDATE CONVERSATION ============
  Future<void> _updateConversation({
    required String userId,
    required String contactPhone,
    required String contactName,
    required String lastMessage,
    required String lastMessageType,
    bool isManualHumanReply = true,
  }) async {
    final phone = PhoneUtils.normalize(contactPhone);
    final data = <String, dynamic>{
      'contactName': contactName,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };

    // When human agent sends a manual reply, flag conversation for AI handoff
    if (isManualHumanReply) {
      data['humanTookOver'] = true;
      data['humanTookOverAt'] = FieldValue.serverTimestamp();
      data['aiHandoffSent'] = false; // Reset so handoff msg can fire again later
    }

    await _firestore.user(userId)
        .collection('conversations')
        .doc(phone)
        .set(data, SetOptions(merge: true));
  }

  // ============ UPDATE MESSAGE STATUS ============
  Future<void> updateMessageStatus({
    required String userId,
    required String whatsappMessageId,
    required MessageStatus status,
  }) async {
    final query = await _firestore.user(userId)
        .collection('messages')
        .where('whatsappMessageId', isEqualTo: whatsappMessageId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final updates = <String, dynamic>{'status': status.name};
      if (status == MessageStatus.delivered) {
        updates['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (status == MessageStatus.read) {
        updates['readAt'] = FieldValue.serverTimestamp();
      }
      await query.docs.first.reference.update(updates);
    }
  }

  // ============ 24-HOUR REPLY WINDOW HELPERS ============
  /// Returns:
  ///   true  → window is open (safe to send free-form)
  ///   false → window is provably closed (block send with template hint)
  ///   null  → indeterminate (Firestore error) — caller should NOT block
  Future<bool?> _isReplyWindowOpen(String userId, String contactPhone) async {
    try {
      final now = DateTime.now();

      // 1) Read the conversation doc first (fast path).
      final convDoc = await _firestore.user(userId)
          .collection('conversations')
          .doc(contactPhone)
          .get();
      if (convDoc.exists) {
        final raw = convDoc.data()!['lastIncomingMessageAt'];
        DateTime? ts;
        if (raw is Timestamp) ts = raw.toDate();
        if (raw is String && raw.isNotEmpty) ts = DateTime.tryParse(raw);
        if (ts != null && now.difference(ts).inHours < 24) return true;
      }

      // 2) Slow path — the field may be missing/stale (older webhook writes, or a
      //    reaction/system event we intentionally do not persist). Scan the last
      //    24h of inbound messages for a real window-opening type.
      final cutoff = now.subtract(const Duration(hours: 24));
      const windowOpeningTypes = <String>{
        'text', 'image', 'video', 'audio', 'document',
        'location', 'contact', 'interactive', 'button', 'order',
      };
      final snap = await _firestore.user(userId)
          .collection('messages')
          .where('contactPhone', isEqualTo: contactPhone)
          .where('direction', isEqualTo: MessageDirection.incoming.name)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      DateTime? latest;
      for (final d in snap.docs) {
        final data = d.data();
        final type = (data['type'] as String?) ?? 'text';
        if (!windowOpeningTypes.contains(type)) continue;
        final ca = data['createdAt'];
        if (ca is Timestamp) { latest = ca.toDate(); break; }
        if (ca is String) { latest = DateTime.tryParse(ca); if (latest != null) break; }
      }
      if (latest != null && now.difference(latest).inHours < 24) {
        // Self-heal: write the discovered value back so the banner + next
        // pre-check agree without another scan.
        try {
          await _firestore.user(userId)
              .collection('conversations')
              .doc(contactPhone)
              .set({'lastIncomingMessageAt': Timestamp.fromDate(latest)},
                  SetOptions(merge: true));
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[MessageRepo] _isReplyWindowOpen error: $e');
      return null; // indeterminate — do not block
    }
  }

  /// Clears lastIncomingMessageAt on all matching conversation docs. Called when
  /// WhatsApp rejects with error 131047 / 131051 / 131026 so the banner immediately
  /// reflects reality instead of continuing to show "window open".
  Future<void> _clearLastIncomingMessageTime(String userId, String contactPhone) async {
    final docs = await _findAllConversationDocs(userId, contactPhone);
    for (final doc in docs) {
      try {
        await doc.update({'lastIncomingMessageAt': FieldValue.delete()});
      } catch (_) {}
    }
  }

  /// Returns true if the WhatsApp API error indicates the 24-hour reply
  /// window is closed (re-engagement required).
  bool _isWindowClosedError(String? errorMsg, dynamic errorData) {
    final msg = (errorMsg ?? '').toLowerCase();
    if (msg.contains('24 hours') ||
        msg.contains('re-engagement') ||
        msg.contains('reengagement') ||
        msg.contains('outside the allowed window') ||
        msg.contains('customer service window')) {
      return true;
    }
    if (errorData is Map) {
      final code = errorData['code']?.toString() ?? '';
      if (code == '131047' || code == '131051' || code == '131026') return true;
    }
    return false;
  }

  // ============ UPDATE LAST INCOMING MESSAGE TIME (Repair) ============
  Future<void> updateLastIncomingMessageTime(String userId, String contactPhone, DateTime timestamp) async {
    final docs = await _findAllConversationDocs(userId, contactPhone);
    for (final doc in docs) {
      try {
        await doc.set({
          'lastIncomingMessageAt': Timestamp.fromDate(timestamp),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // ============ DELETE CONVERSATION ONLY ============
  Future<void> deleteConversation(String userId, String contactPhone) async {
    final docs = await _findAllConversationDocs(userId, contactPhone);
    final foundIds = docs.map((d) => d.id).toSet();
    
    // Also include the requested phone variants just in case no doc was found but messages exist
    foundIds.add(contactPhone);
    foundIds.add(PhoneUtils.normalize(contactPhone));
    foundIds.add(contactPhone.trim());

    // Delete all conversation docs
    for (final doc in docs) {
      try { await doc.delete(); } catch (_) {}
    }

    // Fire-and-forget message deletion in background to keep UI snappy
    _deleteMessagesBackground(userId, foundIds.toList());
  }

  Future<void> _deleteMessagesBackground(String userId, List<String> phones) async {
    final uniquePhones = phones.toSet();
    final List<DocumentSnapshot> allDocs = [];

    for (final p in uniquePhones) {
      final snap = await _firestore.user(userId)
          .collection('messages')
          .where('contactPhone', isEqualTo: p)
          .get();
      allDocs.addAll(snap.docs);
    }

    for (var i = 0; i < allDocs.length; i += 490) {
      final chunk = allDocs.sublist(i, i + 490 > allDocs.length ? allDocs.length : i + 490);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ============ DELETE CONVERSATION + ALL MESSAGES (Old) ============
  Future<void> deleteConversationAndMessages(String userId, String contactPhone) async {
    await deleteConversation(userId, contactPhone);
  }

  // ============ PIN CONVERSATION (max 3) ============
  Future<bool> togglePin(String userId, String contactPhone) async {
    final convRef = _firestore.user(userId).collection('conversations').doc(contactPhone);
    final doc = await convRef.get();
    if (!doc.exists) return false;

    final data = doc.data()!;
    final isPinned = data['isPinned'] ?? false;

    if (!isPinned) {
      // Check max 3 pinned
      final pinned = await _firestore.user(userId)
          .collection('conversations')
          .where('isPinned', isEqualTo: true)
          .get();
      if (pinned.docs.length >= 3) return false; // Max 3 reached

      await convRef.update({
        'isPinned': true,
        'pinOrder': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await convRef.update({
        'isPinned': false,
        'pinOrder': 0,
      });
    }
    return true;
  }

  // ============ CONVERSATION TAGS ============
  Future<void> addTag(String userId, String contactPhone, String tag) async {
    await _firestore.user(userId).collection('conversations').doc(contactPhone).update({
      'tags': FieldValue.arrayUnion([tag]),
    });
  }

  Future<void> removeTag(String userId, String contactPhone, String tag) async {
    await _firestore.user(userId).collection('conversations').doc(contactPhone).update({
      'tags': FieldValue.arrayRemove([tag]),
    });
  }

  Future<void> setTags(String userId, String contactPhone, List<String> tags) async {
    await _firestore.user(userId).collection('conversations').doc(contactPhone).update({
      'tags': tags,
    });
  }

  // ============ USER TAGS (tag definitions with colors) ============
  Stream<List<Map<String, dynamic>>> getUserTags(String userId) {
    return _firestore.user(userId).collection('tags')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Future<void> createTag(String userId, String name, String color) async {
    await _firestore.user(userId).collection('tags').add({
      'name': name,
      'color': color,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTag(String userId, String tagId) async {
    try {
      // 1. Get the tag name first
      final tagDoc = await _firestore.user(userId).collection('tags').doc(tagId).get();
      final tagName = tagDoc.data()?['name'] as String?;

      // 2. Remove tag from all conversations that have it
      if (tagName != null && tagName.isNotEmpty) {
        final convSnap = await _firestore.user(userId).collection('conversations')
            .where('tags', arrayContains: tagName)
            .get();
        for (final doc in convSnap.docs) {
          await doc.reference.update({
            'tags': FieldValue.arrayRemove([tagName]),
          });
        }
      }

      // 3. Delete the tag document
      await _firestore.user(userId).collection('tags').doc(tagId).delete();
    } catch (e) {
      debugPrint('deleteTag error: $e');
    }
  }

  Future<void> updateTag(String userId, String tagId, String name, String color) async {
    await _firestore.user(userId).collection('tags').doc(tagId).update({
      'name': name,
      'color': color,
    });
  }
}

