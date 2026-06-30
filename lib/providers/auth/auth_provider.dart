import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user/user_model.dart';
import 'auth_notifier.dart';
import 'auth_state.dart';

// ============ REPOSITORIES ============
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// ============ AUTH NOTIFIER ============
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  return AuthNotifier(authRepo, userRepo);
});

// ============ SELECTORS ============
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

/// Stable user ID — only changes on login/logout, NOT on user data updates.
/// Use this in stream providers to prevent unnecessary stream re-subscriptions.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).user?.id;
});

/// Data owner ID — if user is an agent, returns owner's ID for shared data access.
/// All data providers (messages, bots, contacts, etc.) should use this instead of userIdProvider.
final dataOwnerIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return null;
  return user.dataOwner ?? user.id;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role.isAdmin ?? false;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).error;
});

/// Streams the data owner's user model — for dashboard stats.
/// When user is agent, this returns the owner's doc (with correct counts).
/// When user is the owner, returns their own doc.
final dataOwnerUserProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return Stream.value(null);
  
  final ownerId = user.dataOwner ?? user.id;
  if (ownerId == user.id) {
    // User IS the owner — use existing stream
    return Stream.value(ref.watch(authNotifierProvider).user);
  }
  
  // User is an agent — stream the owner's user doc
  return FirebaseFirestore.instance
      .collection('users')
      .doc(ownerId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  });
});

