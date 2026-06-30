import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/bot/bot_model.dart';
import '../../data/repositories/bot_repository.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final botRepositoryProvider = Provider<BotRepository>((ref) {
  return BotRepository();
});

// ============ BOTS LIST (REALTIME) ============
final botsProvider = StreamProvider<List<BotModel>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(botRepositoryProvider);
  return repo.getBots(ownerId);
});

// ============ ACTIVE BOTS ============
final activeBotsProvider = StreamProvider<List<BotModel>>((ref) {
  final ownerId = ref.watch(dataOwnerIdProvider);
  if (ownerId == null) return Stream.value([]);

  final repo = ref.watch(botRepositoryProvider);
  return repo.getActiveBots(ownerId);
});

// ============ BOT MANAGEMENT NOTIFIER ============
class BotNotifier extends StateNotifier<BotActionState> {
  final BotRepository _repo;
  final String _userId;

  BotNotifier(this._repo, this._userId) : super(const BotActionState());

  Future<bool> create(BotModel bot) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createBot(_userId, bot);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> update(BotModel bot) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateBot(_userId, bot);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> toggleActive(String botId, bool isActive) async {
    try {
      await _repo.toggleActive(_userId, botId, isActive);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String botId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteBot(_userId, botId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class BotActionState {
  final bool isLoading;
  final String? error;

  const BotActionState({this.isLoading = false, this.error});

  BotActionState copyWith({bool? isLoading, String? error}) {
    return BotActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final botNotifierProvider =
    StateNotifierProvider<BotNotifier, BotActionState>((ref) {
  final repo = ref.watch(botRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.dataOwner ?? user?.id ?? '';
  return BotNotifier(repo, ownerId);
});
