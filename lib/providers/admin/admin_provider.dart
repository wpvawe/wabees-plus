import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user/user_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/plan_repository.dart';

// ============ REPOSITORY ============
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final _planRepoForAdminProvider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});

// ============ ALL USERS (REALTIME) ============
final adminUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllUsers();
});

// ============ PENDING USERS (REALTIME) ============
final pendingUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getPendingUsers();
});

// ============ ONLINE USERS (REALTIME) ============
final onlineUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getOnlineUsers();
});

// ============ ONLINE COUNT (REALTIME) ============
final onlineUsersCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.watchOnlineCount();
});

// ============ PLATFORM STATS (ONE-TIME) ============
final platformStatsProvider = FutureProvider<Map<String, int>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getPlatformStats();
});

// ============ PLATFORM STATS (REALTIME STREAM) ============
final liveStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.watchPlatformStats();
});

// ============ ADMIN NOTIFICATIONS (Bug 7) ============
// Streams unread admin_notifications so admin sees new user registrations in real-time
final adminNewNotificationsCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('admin_notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

// Mark all admin_notifications as read
Future<void> markAdminNotificationsRead() async {
  final snap = await FirebaseFirestore.instance
      .collection('admin_notifications')
      .where('read', isEqualTo: false)
      .get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snap.docs) {
    batch.update(doc.reference, {'read': true});
  }
  await batch.commit();
}

// ============ ADMIN ACTIONS NOTIFIER ============
class AdminNotifier extends StateNotifier<AdminActionState> {
  final AdminRepository _repo;
  final PlanRepository _planRepo;

  AdminNotifier(this._repo, this._planRepo) : super(const AdminActionState());

  Future<bool> approveUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Set user status to active
      await _repo.updateUserStatus(userId, 'active');

      // 2. Auto-assign welcome plan if user has no subscription yet
      //    This covers the case where assignWelcomePlan failed silently at signup
      try {
        final sub = await _planRepo.getSubscriptionOnce(userId);
        if (sub == null) {
          // No subscription at all — assign welcome plan now
          await _planRepo.assignWelcomePlan(userId);
        }
      } catch (_) {
        // Non-critical — subscription will be created lazily
      }

      // 3. Notify user about approval
      await FirebaseFirestore.instance
          .collection('users').doc(userId).collection('notifications').add({
        'title': 'Account Approved! \u{1F389}',
        'body': 'Your account has been approved. You can now use all features.',
        'type': 'user_approved',
        'data': {},
        'read': false,
        'createdAt': Timestamp.now(),
      });

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> suspendUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateUserStatus(userId, 'suspended');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deactivateUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateUserStatus(userId, 'deactivated');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> reactivateUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateUserStatus(userId, 'active');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateUserRole(userId, role);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateUserField(String userId, String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({field: value});
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

class AdminActionState {
  final bool isLoading;
  final String? error;

  const AdminActionState({this.isLoading = false, this.error});

  AdminActionState copyWith({bool? isLoading, String? error}) {
    return AdminActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final adminNotifierProvider =
    StateNotifierProvider<AdminNotifier, AdminActionState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  final planRepo = ref.watch(_planRepoForAdminProvider);
  return AdminNotifier(repo, planRepo);
});
