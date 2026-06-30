import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 🔐 FIREBASE AUTH DATA SOURCE
class FirebaseAuthDs {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  // ============ CURRENT USER ============
  User? get currentUser => _auth.currentUser;

  // ============ AUTH STATE STREAM ============
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============ LOGIN ============
  Future<User?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  // ============ REGISTER ============
  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  // ============ ENSURE GSI INITIALIZED ============
  // serverClientId = web client (type 3) from google-services.json
  // This is REQUIRED in google_sign_in v7+ — without it, initialize()
  // throws "configuration error" on Android even if google-services.json is present.
  static const _webClientId =
      '221545100008-54ei7sl8r2ejbv5fgdiqlv09a255hrsr.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
      _googleInitialized = true;
    }
  }

  // ============ GOOGLE SIGN-IN (Interactive — v7.x API) ============
  Future<User?> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    // Trigger interactive Google sign-in
    // In v7, authenticate() throws GoogleSignInException on cancel — caller handles it
    final account = await GoogleSignIn.instance.authenticate();

    // Get idToken — v7: authentication is NOT a Future, direct access
    final authData = account.authentication;
    final idToken = authData.idToken;
    if (idToken == null) {
      debugPrint('[AUTH] ❌ Google idToken is null — SHA-1 may not be registered in Firebase Console');
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in failed (no ID token). Ensure SHA-1 is added in Firebase Console.',
      );
    }

    // Create Firebase credential and sign in
    // Note: google_sign_in v7.2.0 only exposes idToken (no accessToken)
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final authResult = await _auth.signInWithCredential(credential);
    return authResult.user;
  }

  // ============ GOOGLE SILENT RE-AUTH (for app restart session restore) ============
  //
  // KEY INSIGHT: Firebase Auth stores its OWN refresh token independently of
  // the Google Sign-In SDK. So on app restart:
  //   1. _auth.currentUser is already non-null if Firebase has a valid session
  //   2. authStateChanges() fires the cached user automatically
  //   3. We do NOT need google_sign_in at all for session persistence
  //
  // This method is ONLY reached if Firebase's own session has truly expired
  // (revoked token, account deletion, etc.). In that case, Google SDK silent
  // auth is a best-effort fallback.
  Future<User?> signInWithGoogleSilently() async {
    // ── STEP 1: Firebase already has the user? ────────────────────────────
    // Firebase Auth maintains tokens independent of the Google SDK.
    // reload() verifies the token is still valid server-side.
    final existingUser = _auth.currentUser;
    if (existingUser != null) {
      try {
        await existingUser.reload();
        final refreshed = _auth.currentUser;
        if (refreshed != null) {
          debugPrint('[AUTH] ✅ Firebase session still valid (via reload)');
          return refreshed;
        }
      } catch (e) {
        debugPrint('[AUTH] ⚠️ Firebase reload failed: $e — trying Google SDK fallback');
      }
    }

    // ── STEP 2: Google SDK lightweight auth (best-effort on Android) ──────
    // attemptLightweightAuthentication() returns null when:
    //   • Android Credential Manager has no cached account
    //   • Device doesn't support credential manager
    //   • App data was cleared
    // This is NORMAL — returning null just means "no silent session available"
    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) {
        debugPrint('[AUTH] Google SDK returned no cached account (normal on cold start)');
        return null;
      }

      // v7: authentication is NOT a Future — direct access
      final authData = account.authentication;
      final idToken = authData.idToken;
      if (idToken == null) {
        debugPrint('[AUTH] ⚠️ Google silent auth: idToken is null');
        return null;
      }

      // Note: google_sign_in v7.2.0 only exposes idToken (no accessToken)
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final authResult = await _auth.signInWithCredential(credential);
      debugPrint('[AUTH] ✅ Google SDK silent auth success');
      return authResult.user;
    } catch (e) {
      debugPrint('[AUTH] Google silent auth exception (non-fatal): $e');
      return null;
    }
  }

  // ============ LOGOUT ============
  Future<void> logout() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  // ============ RESET PASSWORD ============
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ============ UPDATE PROFILE ============
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }
}
