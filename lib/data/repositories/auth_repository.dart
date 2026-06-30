import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase/firebase_auth_ds.dart';

/// 🔐 AUTH REPOSITORY
class AuthRepository {
  final FirebaseAuthDs _authDs = FirebaseAuthDs();

  // ============ CURRENT USER ============
  User? get currentUser => _authDs.currentUser;

  // ============ AUTH STATE STREAM ============
  Stream<User?> get authStateChanges => _authDs.authStateChanges;

  // ============ LOGIN ============
  Future<User?> login(String email, String password) async {
    return await _authDs.login(email, password);
  }

  // ============ REGISTER ============
  Future<User?> register(String email, String password) async {
    return await _authDs.register(email, password);
  }

  // ============ GOOGLE SIGN-IN ============
  Future<User?> signInWithGoogle() async {
    return await _authDs.signInWithGoogle();
  }

  // ============ GOOGLE SIGN-IN (Silent — no UI, for re-auth) ============
  Future<User?> signInWithGoogleSilently() async {
    return await _authDs.signInWithGoogleSilently();
  }

  // ============ LOGOUT ============
  Future<void> logout() async {
    await _authDs.logout();
  }

  // ============ RESET PASSWORD ============
  Future<void> resetPassword(String email) async {
    await _authDs.resetPassword(email);
  }
}
