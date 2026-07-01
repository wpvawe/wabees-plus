import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../models/support/support_chat_model.dart';
import '../models/support/support_message_model.dart';
import '../models/notification/app_notification_model.dart';

/// 💬 SUPPORT REPOSITORY — Admin-User 1:1 chat with rate limiting + security
class SupportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.wabees.live',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // ============ RATE LIMITING ============
  final Map<String, List<DateTime>> _sendTimes = {};
  static const _maxMessagesPerWindow = 5;
  static const _windowDuration = Duration(seconds: 10);
  static const _maxMessageLength = 1000;
  static const _maxImageSizeBytes = 5 * 1024 * 1024; // 5MB

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('support_chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  // ============ RATE LIMIT CHECK ============
  String? _checkRateLimit(String userId) {
    final now = DateTime.now();
    final times = _sendTimes[userId] ?? [];

    // Remove old entries outside window
    times.removeWhere((t) => now.difference(t) > _windowDuration);
    _sendTimes[userId] = times;

    if (times.length >= _maxMessagesPerWindow) {
      return 'Slow down! Max $_maxMessagesPerWindow messages per ${_windowDuration.inSeconds}s.';
    }
    return null;
  }

  void _recordSend(String userId) {
    _sendTimes.putIfAbsent(userId, () => []);
    _sendTimes[userId]!.add(DateTime.now());
  }

  // ============ INPUT SANITIZATION ============
  String _sanitize(String input) {
    // Remove HTML tags and script injections
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();
  }

  // ============ GET OR CREATE CHAT ============
  Future<SupportChatModel> getOrCreateChat({
    required String userId,
    required String userName,
    String userEmail = '',
  }) async {
    final doc = await _chats.doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return SupportChatModel.fromJson(doc.data()!, doc.id);
    }

    final chat = SupportChatModel(
      id: userId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      createdAt: DateTime.now(),
    );
    await _chats.doc(userId).set(chat.toJson());
    return chat;
  }

  // ============ SEND TEXT MESSAGE ============
  Future<SupportMessageModel?> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String body,
  }) async {
    // Rate limit
    final rateLimitError = _checkRateLimit(senderId);
    if (rateLimitError != null) throw Exception(rateLimitError);

    // Validate
    final sanitized = _sanitize(body);
    if (sanitized.isEmpty) throw Exception('Message cannot be empty');
    if (sanitized.length > _maxMessageLength) {
      throw Exception('Message too long (max $_maxMessageLength chars)');
    }

    final msgRef = _messages(chatId).doc();
    final message = SupportMessageModel(
      id: msgRef.id,
      senderId: senderId,
      senderRole: senderRole,
      body: sanitized,
      createdAt: DateTime.now(),
    );

    await msgRef.set(message.toJson());

    // Update chat metadata
    final unreadField = senderRole == 'user' ? 'unreadCountAdmin' : 'unreadCountUser';
    await _chats.doc(chatId).set({
      'userId': chatId,
      'lastMessage': sanitized.length > 50 ? '${sanitized.substring(0, 50)}...' : sanitized,
      'lastMessageAt': FieldValue.serverTimestamp(),
      unreadField: FieldValue.increment(1),
    }, SetOptions(merge: true));

    _recordSend(senderId);

    // Create notification for recipient
    await _createSupportNotification(
      chatId: chatId,
      senderRole: senderRole,
      message: sanitized,
    );
    // Also push an admin FCM from server (for background/closed app)
    if (senderRole == 'user') {
      try {
        await _dio.post('/notify_admin.php', data: {
          'type': 'support_message',
          'title': 'New Support Message',
          'body': sanitized.length > 100 ? '${sanitized.substring(0, 100)}...' : sanitized,
        });
      } catch (_) {}
    }

    return message;
  }

  // ============ SEND IMAGE (INSTANT DISPLAY + BACKGROUND UPLOAD) ============
  Future<SupportMessageModel?> sendImage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required File imageFile,
    String caption = '',
  }) async {
    // Rate limit
    final rateLimitError = _checkRateLimit(senderId);
    if (rateLimitError != null) throw Exception(rateLimitError);

    // Validate file size
    final fileSize = await imageFile.length();
    if (fileSize > _maxImageSizeBytes) {
      throw Exception('Image too large (max 5MB)');
    }

    // Validate file type
    final ext = imageFile.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      throw Exception('Only JPG, PNG, WEBP images allowed');
    }

    // Sanitize caption
    final sanitizedCaption = caption.isNotEmpty ? _sanitize(caption) : '';

    // 1. Save message to Firestore IMMEDIATELY with local file path
    //    This makes the image appear in the chat instantly
    final msgRef = _messages(chatId).doc();
    final localPath = imageFile.path;
    final message = SupportMessageModel(
      id: msgRef.id,
      senderId: senderId,
      senderRole: senderRole,
      body: sanitizedCaption.isNotEmpty ? sanitizedCaption : '📷 Image',
      imageUrl: localPath, // Local file path for instant display
      createdAt: DateTime.now(),
    );

    await msgRef.set(message.toJson());

    // Update chat metadata immediately
    final unreadField = senderRole == 'user' ? 'unreadCountAdmin' : 'unreadCountUser';
    await _chats.doc(chatId).set({
      'userId': chatId,
      'lastMessage': '📷 Image',
      'lastMessageAt': FieldValue.serverTimestamp(),
      unreadField: FieldValue.increment(1),
    }, SetOptions(merge: true));

    _recordSend(senderId);

    // 2. Upload to server in BACKGROUND (non-blocking)
    _uploadImageInBackground(
      msgRef: msgRef,
      imageFile: imageFile,
      chatId: chatId,
      ext: ext,
    );

    return message;
  }

  /// Uploads image to server and updates Firestore doc with server URL
  Future<void> _uploadImageInBackground({
    required dynamic msgRef,
    required File imageFile,
    required String chatId,
    required String ext,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: '${chatId}_$timestamp.$ext',
        ),
      });

      final response = await _dio.post('/upload-image.php', data: formData);
      final data = response.data;

      if (data['success'] == true && data['url'] != null) {
        // Update Firestore doc with server URL
        await msgRef.update({'imageUrl': data['url']});
      }
    } catch (_) {
      // Upload failed silently — local image still visible
    }
  }


  // ============ MESSAGES STREAM (REALTIME) ============
  Stream<List<SupportMessageModel>> getMessages(String chatId) {
    return _messages(chatId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SupportMessageModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ ADMIN: ALL CHATS STREAM ============
  Stream<List<SupportChatModel>> getAdminChats() {
    return _chats
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SupportChatModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ USER: SINGLE CHAT STREAM ============
  Stream<SupportChatModel?> getChatStream(String userId) {
    return _chats.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SupportChatModel.fromJson(doc.data()!, doc.id);
    });
  }

  // ============ MARK AS READ ============
  Future<void> markAsRead(String chatId, String readerRole) async {
    try {
      // Reset unread count for reader — use set+merge to avoid 'not-found' crash
      final field = readerRole == 'user' ? 'unreadCountUser' : 'unreadCountAdmin';
      await _chats.doc(chatId).set({field: 0}, SetOptions(merge: true));

      // Mark individual messages as read
      final otherRole = readerRole == 'user' ? 'admin' : 'user';
      final unread = await _messages(chatId)
          .where('senderRole', isEqualTo: otherRole)
          .where('readAt', isNull: true)
          .get();

      if (unread.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in unread.docs) {
          batch.update(doc.reference, {'readAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }
    } catch (_) {
      // Silently ignore — chat may not exist yet
    }
  }

  // ============ ONLINE STATUS ============
  Future<void> setOnlineStatus(String chatId, String role, bool isOnline) async {
    final field = role == 'user' ? 'userOnline' : 'adminOnline';
    try {
      await _chats.doc(chatId).update({field: isOnline});
    } catch (_) {
      // Chat may not exist yet
    }
  }

  // ============ ADMIN TOTAL UNREAD ============
  Stream<int> getAdminTotalUnread() {
    return _chats.snapshots().map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['unreadCountAdmin'] as int?) ?? 0;
      }
      return total;
    });
  }

  // ============ CREATE NOTIFICATION ============
  Future<void> _createSupportNotification({
    required String chatId,
    required String senderRole,
    required String message,
  }) async {
    try {
      final notification = AppNotificationModel(
        id: '',
        title: senderRole == 'user' ? 'New Support Message' : 'Admin Reply',
        body: message.length > 100 ? '${message.substring(0, 100)}...' : message,
        type: 'new_support_message',
        data: {'chatId': chatId, 'senderRole': senderRole},
        createdAt: DateTime.now(),
      );

      if (senderRole == 'user') {
        // Notify admin
        await _db.collection('admin_notifications').add(notification.toJson());
      } else {
        // Notify user
        await _db.collection('users').doc(chatId).collection('notifications').add(notification.toJson());
      }
    } catch (_) {
      // Non-critical — notification failure should not block chat
    }
  }
}
