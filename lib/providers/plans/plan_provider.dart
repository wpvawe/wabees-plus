import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/plan/plan_model.dart';
import '../../data/models/plan/subscription_model.dart';
import '../../data/models/user/user_status.dart';
import '../../data/repositories/plan_repository.dart';
import '../auth/auth_provider.dart';


// ============ REPOSITORY ============
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});

// ============ ACTIVE PLANS (USER VIEW) ============
final plansProvider = StreamProvider<List<PlanModel>>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPlans();
});

// ============ ALL PLANS (ADMIN VIEW) ============
final allPlansProvider = StreamProvider<List<PlanModel>>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getAllPlans();
});

// ============ USER SUBSCRIPTION (REALTIME) ============
final subscriptionProvider = StreamProvider<SubscriptionModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  // Read subscription from owner's path (phone-number-based)
  final ownerId = user.dataOwner ?? user.id;
  final repo = ref.watch(planRepositoryProvider);
  return repo.getSubscription(ownerId);
});

// ============ ADMIN: ANY USER'S SUBSCRIPTION ============
final adminUserSubscriptionProvider =
    StreamProvider.family<SubscriptionModel?, String>((ref, userId) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getSubscription(userId);
});

// ============ IS SUBSCRIPTION ACTIVE ============
final isSubscriptionActiveProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  return sub != null && sub.isActive;
});

// ============ SUBSCRIPTION EXPIRY DAYS ============
final subscriptionDaysRemainingProvider = Provider<int>((ref) {
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  if (sub == null) return 0;
  return sub.daysRemaining;
});

// ============ CAN PERFORM ACTIONS (PLAN LIMIT CHECKS) ============
final canSendMessageProvider = Provider<bool>((ref) {
  // First check user approval status — pending/suspended users cannot send
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (user.status.isPending || user.status.isSuspended) return false;
  if (user.status == UserStatus.deactivated) return false;

  final asyncSub = ref.watch(subscriptionProvider);
  // Still loading → block sending until we know the subscription state.
  if (asyncSub.isLoading) return false;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return false;
  return sub.isActive && sub.canSendMessage;
});


final canAddContactProvider = Provider<bool>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  if (asyncSub.isLoading) return true;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return true;
  return sub.isActive && sub.canAddContact;
});

final canCreateCampaignProvider = Provider<bool>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  if (asyncSub.isLoading) return true;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return true;
  return sub.isActive && sub.canCreateCampaign;
});

final canCreateBotProvider = Provider<bool>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  if (asyncSub.isLoading) return true;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return true;
  return sub.isActive && sub.canCreateBot;
});

final canCreateTemplateProvider = Provider<bool>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  if (asyncSub.isLoading) return true;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return true;
  return sub.isActive && sub.canCreateTemplate;
});

final canUseAiBotProvider = Provider<bool>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  if (asyncSub.isLoading) return true;
  final sub = asyncSub.valueOrNull;
  if (sub == null) return true;
  return sub.isActive && sub.canUseAiBot;
});

// ============ PENDING SUBSCRIPTIONS (ADMIN) ============
final pendingSubscriptionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPendingSubscriptions();
});

// ============ PLAN MANAGEMENT NOTIFIER ============
class PlanNotifier extends StateNotifier<PlanActionState> {
  final PlanRepository _repo;
  final String _userId;

  PlanNotifier(this._repo, this._userId) : super(const PlanActionState());

  // Admin: create plan
  Future<bool> createPlan(PlanModel plan) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createPlan(plan);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Admin: update plan
  Future<bool> updatePlan(PlanModel plan) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updatePlan(plan);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Admin: delete plan
  Future<bool> deletePlan(String planId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deletePlan(planId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // User: request subscription (pending → admin activates)
  Future<bool> requestSubscription(PlanModel plan) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.requestSubscription(_userId, plan);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Admin: activate subscription
  Future<bool> activateSubscription(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.activateSubscription(userId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Admin: reject subscription
  Future<bool> rejectSubscription(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.rejectSubscription(userId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Admin: upgrade plan with merge
  Future<bool> upgradePlan(String userId, PlanModel plan) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.upgradePlan(userId, plan);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // User: cancel subscription
  Future<bool> cancelSubscription() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.cancelSubscription(_userId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class PlanActionState {
  final bool isLoading;
  final String? error;

  const PlanActionState({this.isLoading = false, this.error});

  PlanActionState copyWith({bool? isLoading, String? error}) {
    return PlanActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final planNotifierProvider =
    StateNotifierProvider<PlanNotifier, PlanActionState>((ref) {
  final repo = ref.watch(planRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.dataOwner ?? user?.id ?? '';
  return PlanNotifier(repo, ownerId);
});
