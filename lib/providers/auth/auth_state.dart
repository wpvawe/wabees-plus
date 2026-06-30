import 'package:flutter/foundation.dart';
import '../../data/models/user/user_model.dart';

/// 🎯 AUTH STATE - Immutable
@immutable
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  factory AuthState.initial() => const AuthState(isLoading: true);

  factory AuthState.loading() => const AuthState(isLoading: true);

  factory AuthState.authenticated(UserModel user) => AuthState(
    user: user,
    isAuthenticated: true,
  );

  factory AuthState.unauthenticated() => const AuthState(
    isAuthenticated: false,
  );

  factory AuthState.error(String message) => AuthState(
    error: message,
  );

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
