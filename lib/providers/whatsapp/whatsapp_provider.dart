import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/whatsapp/whatsapp_config.dart';
import '../../data/models/whatsapp/whatsapp_api_response.dart';
import '../../data/repositories/whatsapp_repository.dart';
import '../auth/auth_provider.dart';
import '../messaging/messaging_provider.dart';

// ============ REPOSITORY ============
final whatsappRepositoryProvider = Provider<WhatsappRepository>((ref) {
  return WhatsappRepository();
});

// ============ CONFIG STREAM (REALTIME) ============
final whatsappConfigProvider = StreamProvider<WhatsappConfig>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value(WhatsappConfig.empty());

  final repo = ref.watch(whatsappRepositoryProvider);
  return repo.getConfigStream(userId);
});

// ============ IS CONNECTED ============
final whatsappConnectedProvider = Provider<bool>((ref) {
  final config = ref.watch(whatsappConfigProvider);
  return config.whenOrNull(data: (c) => c.isConnected) ?? false;
});

// ============ CONNECTION NOTIFIER ============
class WhatsappConnectionNotifier extends StateNotifier<WhatsappConnectionState> {
  final WhatsappRepository _repo;
  final String _userId;

  WhatsappConnectionNotifier(this._repo, this._userId)
      : super(const WhatsappConnectionState());

  Future<void> verifyAndConnect({
    required String phoneNumberId,
    required String accessToken,
    String businessAccountId = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: null);

    final result = await _repo.verifyAndConnect(
      userId: _userId,
      phoneNumberId: phoneNumberId,
      accessToken: accessToken,
      businessAccountId: businessAccountId,
    );

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        success: 'WhatsApp connected successfully! ✅',
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message ?? 'Connection failed',
      );
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true, error: null, success: null);

    try {
      await _repo.disconnect(_userId);
      state = state.copyWith(
        isLoading: false,
        success: 'WhatsApp disconnected',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to disconnect: $e',
      );
    }
  }

  Future<WhatsappApiResponse> sendTestMessage(String to) async {
    state = state.copyWith(isLoading: true, error: null, success: null);

    final result = await _repo.sendText(
      userId: _userId,
      to: to,
      message: '✅ WABEES Test Message - Your WhatsApp is connected!',
    );

    state = state.copyWith(
      isLoading: false,
      success: result.success ? 'Test message sent!' : null,
      error: result.success ? null : result.message,
    );

    return result;
  }

  void clearMessages() {
    state = state.copyWith(error: null, success: null);
  }
}

// ============ CONNECTION STATE ============
class WhatsappConnectionState {
  final bool isLoading;
  final String? error;
  final String? success;

  const WhatsappConnectionState({
    this.isLoading = false,
    this.error,
    this.success,
  });

  WhatsappConnectionState copyWith({
    bool? isLoading,
    String? error,
    String? success,
  }) {
    return WhatsappConnectionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success,
    );
  }
}

// ============ CONNECTION NOTIFIER PROVIDER ============
final whatsappConnectionProvider =
    StateNotifierProvider<WhatsappConnectionNotifier, WhatsappConnectionState>((ref) {
  final repo = ref.watch(whatsappRepositoryProvider);
  final userId = ref.watch(userIdProvider) ?? '';
  return WhatsappConnectionNotifier(repo, userId);
});

// ============ WHATSAPP INSIGHTS (Quality + Limits + Templates) ============
// Auto-detects connection status based on API response
final whatsappInsightsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return {};

  final repo = ref.read(whatsappRepositoryProvider);
  final result = await repo.getInsights(userId);

  if (result.success && result.data != null) {
    // Optional: avoid heavy writes here; rely on connect flow to set flag

    final data = Map<String, dynamic>.from(result.data!);

    // Enrich usage_24h with Firestore counts when Meta API returns 0
    final usage = data['usage_24h'] as Map<String, dynamic>? ?? {};
    final metaSent = (usage['sent'] as num?)?.toInt() ?? 0;
    if (metaSent == 0) {
      try {
        final msgRepo = ref.read(messageRepositoryProvider);
        final firestoreSent = await msgRepo.getSentMessageCount24h(userId);
        data['usage_24h'] = {
          'sent': firestoreSent,
          'delivered': firestoreSent, // approximate
          'received': (usage['received'] as num?)?.toInt() ?? 0,
          'source': 'firestore',
        };
      } catch (_) {}
    }

    return data;
  }

  // If API failed with auth error, mark as disconnected
  // If API failed with auth error, we skip toggling flags here to avoid loops

  return {};
});

// ============ WHATSAPP ANALYTICS (Monthly Insights) ============
// Non-family cached provider — fetches ONCE, cached permanently for instant access
final whatsappAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return {};

  // Keep alive — never refetch, instant for all date range switches
  ref.keepAlive();

  try {
    final msgRepo = ref.read(messageRepositoryProvider);
    final counts = await msgRepo.getMessageCountByRange(userId, DateTime(2020), DateTime.now());
    return {
      'messages': {
        'sent': counts['sent'] ?? 0,
        'delivered': counts['sent'] ?? 0,
        'received': counts['received'] ?? 0,
        'daily': [],
        'source': 'firestore',
      },
      'conversations': {},
      'billing': {},
    };
  } catch (_) {
    return {};
  }
});


// ============ PHONE HEALTH & QUALITY RATING ============
final phoneHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return {};

  final repo = ref.read(whatsappRepositoryProvider);
  final result = await repo.getPhoneHealth(userId);

  if (result.success && result.data != null) {
    return result.data!;
  }

  return {};
});

// ============ BUSINESS PROFILE ============
final businessProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return {};

  final repo = ref.read(whatsappRepositoryProvider);
  final result = await repo.getBusinessProfile(userId);

  if (result.success && result.data != null) {
    return (result.data!['profile'] as Map<String, dynamic>?) ?? {};
  }

  return {};
});

// ============ MESSAGE LINKS (wa.me/message/XXX) ============
final messageLinksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return [];

  final repo = ref.read(whatsappRepositoryProvider);
  final result = await repo.getMessageLinks(user.id);

  if (result.success && result.data != null) {
    final links = result.data!['links'] as List? ?? [];
    return links.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  return [];
});


// ============ MESSAGE LINKS NOTIFIER ============
class MessageLinksNotifier extends StateNotifier<MessageLinksState> {
  final WhatsappRepository _repo;
  final String _userId;

  MessageLinksNotifier(this._repo, this._userId) : super(const MessageLinksState());

  Future<bool> createLink(String prefilledMessage) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.createMessageLink(
        userId: _userId,
        prefilledMessage: prefilledMessage,
      );
      if (result.success) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: result.message ?? 'Failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteLink(String linkId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.deleteMessageLink(
        userId: _userId,
        linkId: linkId,
      );
      if (result.success) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: result.message ?? 'Failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class MessageLinksState {
  final bool isLoading;
  final String? error;

  const MessageLinksState({this.isLoading = false, this.error});

  MessageLinksState copyWith({bool? isLoading, String? error}) {
    return MessageLinksState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final messageLinksNotifierProvider =
    StateNotifierProvider<MessageLinksNotifier, MessageLinksState>((ref) {
  final repo = ref.watch(whatsappRepositoryProvider);
  final user = ref.read(currentUserProvider);
  return MessageLinksNotifier(repo, user?.id ?? '');
});
