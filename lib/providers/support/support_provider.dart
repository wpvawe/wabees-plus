import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/support/support_chat_model.dart';
import '../../data/models/support/support_message_model.dart';
import '../../data/repositories/support_repository.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});

// ============ USER CHAT STREAM ============
final userSupportChatProvider = StreamProvider<SupportChatModel?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(null);
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getChatStream(userId);
});

// ============ ADMIN: ALL CHATS ============
final adminSupportChatsProvider = StreamProvider<List<SupportChatModel>>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getAdminChats();
});

// ============ MESSAGES FOR A CHAT ============
final supportMessagesProvider =
    StreamProvider.family<List<SupportMessageModel>, String>((ref, chatId) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getMessages(chatId);
});

// ============ ADMIN TOTAL UNREAD ============
final adminSupportUnreadProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getAdminTotalUnread();
});

// ============ SUPPORT NOTIFIER ============
class SupportNotifier extends StateNotifier<SupportActionState> {
  final SupportRepository _repo;
  final String _userId;
  final String _userName;
  final String _userEmail;

  SupportNotifier(this._repo, this._userId, this._userName, this._userEmail)
      : super(const SupportActionState());

  /// Ensure chat exists and get chatId
  Future<String?> ensureChat() async {
    try {
      final chat = await _repo.getOrCreateChat(
        userId: _userId,
        userName: _userName,
        userEmail: _userEmail,
      );
      return chat.id;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Send text message
  Future<bool> sendMessage(String chatId, String body, {String role = 'user'}) async {
    state = state.copyWith(isSending: true, error: null);
    try {
      await _repo.sendMessage(
        chatId: chatId,
        senderId: _userId,
        senderRole: role,
        body: body,
      );
      state = state.copyWith(isSending: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  /// Send image
  Future<bool> sendImage(String chatId, File imageFile, {String role = 'user', String caption = ''}) async {
    state = state.copyWith(isSending: true, error: null);
    try {
      await _repo.sendImage(
        chatId: chatId,
        senderId: _userId,
        senderRole: role,
        imageFile: imageFile,
        caption: caption,
      );
      state = state.copyWith(isSending: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  /// Mark as read
  Future<void> markAsRead(String chatId, String role) async {
    await _repo.markAsRead(chatId, role);
  }

  /// Set online
  Future<void> setOnline(String chatId, String role, bool online) async {
    await _repo.setOnlineStatus(chatId, role, online);
  }

  void clearError() => state = state.copyWith(error: null);
}

class SupportActionState {
  final bool isSending;
  final String? error;

  const SupportActionState({this.isSending = false, this.error});

  SupportActionState copyWith({bool? isSending, String? error}) {
    return SupportActionState(
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

final supportNotifierProvider =
    StateNotifierProvider<SupportNotifier, SupportActionState>((ref) {
  final repo = ref.watch(supportRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return SupportNotifier(
    repo,
    user?.id ?? '',
    user?.businessName ?? '',
    user?.email ?? '',
  );
});
