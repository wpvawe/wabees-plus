import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message/message_model.dart';
import '../../data/models/message/message_status.dart';
import '../../data/models/message/conversation_model.dart';
import '../../data/repositories/message_repository.dart';
import '../../services/anti_ban_service.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

/// Tracks the currently open chat's contactPhone (normalized).
/// Set when entering a chat, cleared when leaving.
final activeChatPhoneProvider = StateProvider<String?>((ref) => null);

// ============ ANTI-BAN SERVICE ============
final antiBanServiceProvider = Provider<AntiBanService>((ref) {
  // Reset counters when user changes
  // Watch userId so service resets on user change
  ref.watch(userIdProvider);
  final service = AntiBanService();
  // If userId changes, clear state to avoid cross-account pollution
  ref.onDispose(() {
    service.reset();
  });
  return service;
});

// ============ MESSAGING LIMITS ============
final messagingLimitsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {'tier': 'Unknown', 'limit': 0, 'used': 0, 'remaining': 0, 'percentage': 0.0};
  
  return ref.watch(antiBanServiceProvider).getMessagingLimits(user.id);
});

// ============ CONVERSATIONS (REALTIME) ============
final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(messageRepositoryProvider);
  return repo.getConversations(ownerId);
});

// ============ SINGLE CONVERSATION (for 24h reply window) ============
final conversationDetailProvider =
    StreamProvider.family<ConversationModel?, String>((ref, contactPhone) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value(null);

  final repo = ref.watch(messageRepositoryProvider);
  return repo.getConversationStream(ownerId, contactPhone);
});

// ============ MESSAGES FOR CONTACT (REALTIME) ============
final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, contactPhone) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(messageRepositoryProvider);
  return repo.getMessages(ownerId, contactPhone);
});

// ============ TOTAL UNREAD COUNT ============
final totalUnreadProvider = StreamProvider<int>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value(0);

  final repo = ref.watch(messageRepositoryProvider);
  return repo.getTotalUnreadCount(ownerId);
});

// ============ SEND MESSAGE NOTIFIER ============
class SendMessageNotifier extends StateNotifier<SendMessageState> {
  final MessageRepository _repo;
  final AntiBanService _antiBan;
  final String _userId;

  SendMessageNotifier(this._repo, this._antiBan, this._userId)
      : super(const SendMessageState());

  Future<bool> sendText({
    required String contactPhone,
    required String contactName,
    required String text,
  }) async {
    // ===== ANTI-BAN CHECK =====
    final banCheck = _antiBan.canSend(
      contactPhone: contactPhone,
      messageText: text,
    );
    if (banCheck != null) {
      state = state.copyWith(isSending: false, error: '🛡️ $banCheck');
      return false;
    }

    state = state.copyWith(isSending: true, error: null);

    final result = await _repo.sendTextMessage(
      userId: _userId,
      contactPhone: contactPhone,
      contactName: contactName,
      text: text,
    );

    if (result != null && result.status != MessageStatus.failed) {
      // Record successful send for anti-ban tracking
      _antiBan.recordSend(contactPhone: contactPhone, messageText: text);
      state = state.copyWith(isSending: false);
      return true;
    } else {
      state = state.copyWith(
        isSending: false,
        error: result?.errorReason ?? 'Failed to send message',
      );
      return false;
    }
  }

  Future<bool> sendMedia({
    required String contactPhone,
    required String contactName,
    required String mediaType,
    required String mediaUrl,
    String? mediaId,
    String? caption,
    String? fileName,
    int? fileSize,
    bool isVoice = false, // true = real WhatsApp voice note
  }) async {
    // ===== ANTI-BAN CHECK =====
    final banCheck = _antiBan.canSend(
      contactPhone: contactPhone,
      messageText: caption ?? '[$mediaType]',
    );
    if (banCheck != null) {
      state = state.copyWith(isSending: false, error: '🛡️ $banCheck');
      return false;
    }

    state = state.copyWith(isSending: true, error: null);

    final result = await _repo.sendMediaMessage(
      userId: _userId,
      contactPhone: contactPhone,
      contactName: contactName,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaId: mediaId,
      caption: caption,
      fileName: fileName,
      fileSize: fileSize,
      isVoice: isVoice,
    );

    if (result != null && result.status != MessageStatus.failed) {
      // Record successful send for anti-ban tracking
      _antiBan.recordSend(contactPhone: contactPhone, messageText: caption ?? '[$mediaType]');
      state = state.copyWith(isSending: false);
      return true;
    } else {
      state = state.copyWith(
        isSending: false,
        error: result?.errorReason ?? 'Failed to send media',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============ SEND STATE ============
class SendMessageState {
  final bool isSending;
  final String? error;

  const SendMessageState({this.isSending = false, this.error});

  SendMessageState copyWith({bool? isSending, String? error}) {
    return SendMessageState(
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ============ SEND NOTIFIER PROVIDER ============
final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, SendMessageState>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  final antiBan = ref.watch(antiBanServiceProvider);
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.dataOwner ?? user?.id ?? '';
  return SendMessageNotifier(repo, antiBan, ownerId);
});

// ============ USER TAGS (REALTIME) ============
final userTagsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(messageRepositoryProvider);
  return repo.getUserTags(ownerId);
});
