import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/models/user/user_model.dart';
import '../../data/models/user/user_role.dart';
import '../../data/models/user/user_status.dart';
import '../../core/services/user_presence_service.dart';
import '../../core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/services/subscription_expiry_service.dart';
import 'auth_state.dart';
import 'package:dio/dio.dart';

/// 🧠 AUTH NOTIFIER — Real silent re-auth persistence
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  final PlanRepository _planRepo = PlanRepository();
  StreamSubscription? _userSubscription;
  StreamSubscription? _authStateSubscription;
  bool _initialAuthDone = false;
  Completer<void>? _authReadyCompleter;

  // Keys for secure credential storage
  static const _authMethodKey = 'wabees_auth_method';
  static const _emailKey = 'wabees_auth_email';
  static const _passwordKey = 'wabees_auth_password';

  AuthNotifier(this._authRepo, this._userRepo) : super(AuthState.initial()) {
    // PRIMARY auth persistence: Listen to Firebase authStateChanges
    // This stream fires automatically when Firebase restores a persisted user
    _authStateSubscription = _authRepo.authStateChanges.listen((user) async {
      debugPrint('[AUTH] authStateChanges fired: ${user?.uid ?? "NULL"}');
      if (user != null && !state.isAuthenticated) {
        await _authenticateUser(user);
      } else if (user == null && _initialAuthDone && state.isAuthenticated) {
        // User signed out externally
        state = AuthState.unauthenticated();
      }
      _initialAuthDone = true;
      // Signal any waiting checkAuthState() that auth stream has fired
      if (_authReadyCompleter != null && !_authReadyCompleter!.isCompleted) {
        _authReadyCompleter!.complete();
      }
    });
  }

  /// Save credentials for silent re-auth (DUAL STORAGE for maximum reliability)
  Future<void> _saveCredentials({
    required String method, // 'email' or 'google'
    String? email,
    String? password,
  }) async {
    debugPrint('[AUTH] Saving credentials (method: $method)...');
    try {
      // Storage 1: SharedPreferences (always works, not encrypted)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authMethodKey, method);
      if (method == 'email' && email != null && password != null) {
        await prefs.setString(_emailKey, email);
        await prefs.setString(_passwordKey, password);
      }
      debugPrint('[AUTH] ✅ SharedPreferences saved');
    } catch (e) {
      debugPrint('[AUTH] ❌ SharedPreferences save FAILED: $e');
    }
    try {
      // Storage 2: FlutterSecureStorage (encrypted, may fail with R8)
      if (method == 'email' && email != null && password != null) {
        const storage = FlutterSecureStorage();
        await storage.write(key: _emailKey, value: email);
        await storage.write(key: _passwordKey, value: password);
        debugPrint('[AUTH] ✅ SecureStorage saved');
      }
    } catch (e) {
      debugPrint('[AUTH] ⚠️ SecureStorage save failed (SharedPrefs backup exists): $e');
    }
  }

  /// Read saved auth method
  Future<String?> _getSavedAuthMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final method = prefs.getString(_authMethodKey);
      debugPrint('[AUTH] Read auth method: ${method ?? "NULL"}');
      return method;
    } catch (e) {
      debugPrint('[AUTH] Read auth method FAILED: $e');
      return null;
    }
  }

  /// Clear all saved credentials from both storages
  Future<void> _clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authMethodKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
    } catch (_) {}
    try {
      const storage = FlutterSecureStorage();
      await storage.delete(key: _emailKey);
      await storage.delete(key: _passwordKey);
    } catch (_) {}
    debugPrint('[AUTH] All credentials cleared');
  }

  /// Read email/password from dual storage (try secure first, fallback to prefs)
  Future<Map<String, String>?> _readEmailCredentials() async {
    // Try FlutterSecureStorage first
    try {
      const storage = FlutterSecureStorage();
      final email = await storage.read(key: _emailKey);
      final password = await storage.read(key: _passwordKey);
      if (email != null && password != null) {
        debugPrint('[AUTH] Credentials from SecureStorage ✅');
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('[AUTH] SecureStorage read failed: $e');
    }
    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      final password = prefs.getString(_passwordKey);
      if (email != null && password != null) {
        debugPrint('[AUTH] Credentials from SharedPreferences ✅');
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('[AUTH] SharedPreferences read failed: $e');
    }
    debugPrint('[AUTH] No credentials found in any storage');
    return null;
  }

  /// Attempt silent re-authentication using saved credentials
  Future<User?> _attemptSilentReAuth() async {
    final method = await _getSavedAuthMethod();
    debugPrint('[AUTH] Silent re-auth attempt (method: ${method ?? "NONE"})');

    if (method == 'email') {
      try {
        final creds = await _readEmailCredentials();
        if (creds != null) {
          debugPrint('[AUTH] Re-authenticating with email...');
          final user = await _authRepo
              .login(creds['email']!, creds['password']!)
              .timeout(const Duration(seconds: 15));
          debugPrint('[AUTH] Email re-auth: ${user != null ? "SUCCESS ✅" : "FAILED ❌"}');
          return user;
        } else {
          debugPrint('[AUTH] No email credentials found');
        }
      } catch (e) {
        debugPrint('[AUTH] Email re-auth error: $e');
      }
    } else if (method == 'google') {
      try {
        debugPrint('[AUTH] Re-authenticating with Google SILENTLY (no UI)...');
        final user = await _authRepo
            .signInWithGoogleSilently()
            .timeout(const Duration(seconds: 15));
        debugPrint('[AUTH] Google silent re-auth: ${user != null ? "SUCCESS ✅" : "FAILED ❌"}');
        return user;
      } catch (e) {
        debugPrint('[AUTH] Google silent re-auth error: $e');
      }
    }
    return null;
  }

  // ============ LOGIN ============
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepo.login(email, password);
      if (user != null) {
        final userModel = await _userRepo.getUser(user.uid);
        if (userModel != null) {
          if (userModel.status.isSuspended) {
            await _authRepo.logout();
            state = state.copyWith(
                isLoading: false, error: 'Your account has been suspended. Please contact admin.');
            return;
          }
          if (userModel.status == UserStatus.deactivated) {
            await _authRepo.logout();
            state = state.copyWith(
                isLoading: false, error: 'Your account has been deactivated. Please contact admin.');
            return;
          }
          // Save credentials + set state FIRST (before side effects)
          await _saveCredentials(method: 'email', email: email, password: password);
          state = AuthState.authenticated(userModel);
          // Side effects AFTER (non-critical)
          try { _listenToUserChanges(user.uid); } catch (_) {}
          try { _onUserAuthenticated(user.uid); } catch (_) {}
        } else {
          await _authRepo.logout();
          state = state.copyWith(
              isLoading: false, error: 'User data not found. Contact admin.');
        }
      } else {
        state = state.copyWith(isLoading: false, error: 'Login failed');
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _friendlyError(e.toString()));
    }
  }

  // ============ REGISTER ============
  Future<void> register({
    required String email,
    required String password,
    required String businessName,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepo.register(email, password);
      if (user != null) {
        final userModel = UserModel(
          id: user.uid,
          email: email,
          businessName: businessName,
          phoneNumber: phoneNumber,
          role: UserRole.user,
          status: UserStatus.pending,
          createdAt: DateTime.now(),
        );

        await _userRepo.createUser(userModel);
        try { await _planRepo.assignWelcomePlan(user.uid); } catch (_) {}
        // Save credentials + set state FIRST
        await _saveCredentials(method: 'email', email: email, password: password);
        state = AuthState.authenticated(userModel);
        // Side effects AFTER
        try { _listenToUserChanges(user.uid); } catch (_) {}
        try { _onUserAuthenticated(user.uid); } catch (_) {}

        // Bug 7 fix: write to Firestore admin_notifications collection so admin sees
        // new registrations in real-time even if FCM delivery fails.
        try {
          await FirebaseFirestore.instance.collection('admin_notifications').add({
            'type': 'new_user',
            'userId': user.uid,
            'businessName': businessName,
            'email': email,
            'phoneNumber': phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        } catch (_) {}

        // Also notify admins via server-side FCM (secondary channel)
        try {
          final dio = Dio(BaseOptions(
            baseUrl: 'https://api.wabees.live/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ));
          await dio.post('/notify_admin.php', data: {
            'type': 'new_user',
            'userId': user.uid,
            'title': 'New User Registration',
            'body': '$businessName ($email) signed up and is pending approval',
          });
        } catch (_) {}
      } else {
        state = state.copyWith(isLoading: false, error: 'Registration failed');
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _friendlyError(e.toString()));
    }
  }

  // ============ GOOGLE SIGN-IN ============
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authRepo.signInWithGoogle();
      if (user == null) {
        // User cancelled Google sign-in
        state = state.copyWith(isLoading: false);
        return;
      }

      // Check if user exists in Firestore
      var userModel = await _userRepo.getUser(user.uid);

      if (userModel != null) {
        if (userModel.status.isSuspended) {
          await _authRepo.logout();
          state = state.copyWith(
              isLoading: false, error: 'Your account has been suspended');
          return;
        }
        // Save credentials + set state FIRST
        await _saveCredentials(method: 'google');
        state = AuthState.authenticated(userModel);
        // Side effects AFTER
        try { _listenToUserChanges(user.uid); } catch (_) {}
        try { _onUserAuthenticated(user.uid); } catch (_) {}
      } else {
        userModel = UserModel(
          id: user.uid,
          email: user.email ?? '',
          businessName: user.displayName ?? 'My Business',
          phoneNumber: user.phoneNumber ?? '',
          role: UserRole.user,
          status: UserStatus.pending,
          createdAt: DateTime.now(),
        );
        await _userRepo.createUser(userModel);
        try { await _planRepo.assignWelcomePlan(user.uid); } catch (_) {}
        // Save credentials + set state FIRST
        await _saveCredentials(method: 'google');
        state = AuthState.authenticated(userModel);
        // Side effects AFTER
        try { _listenToUserChanges(user.uid); } catch (_) {}
        try { _onUserAuthenticated(user.uid); } catch (_) {}

        // Bug 7 fix: write to Firestore admin_notifications so admin sees
        // new Google-sign-in registrations even if FCM is unreliable.
        try {
          await FirebaseFirestore.instance.collection('admin_notifications').add({
            'type': 'new_user',
            'userId': user.uid,
            'businessName': userModel.businessName,
            'email': userModel.email,
            'phoneNumber': userModel.phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    } on GoogleSignInException catch (e) {
      // Handle Google Sign-In specific errors
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User tapped "Back" or dismissed picker — silently dismiss loading.
        state = state.copyWith(isLoading: false);
      } else {
        // Any other error: could be DEVELOPER_ERROR (SHA-1 not registered,
        // wrong OAuth client ID, or Google Play Services missing), network
        // issue, or account picker failure.
        final msg = e.description ?? e.toString();
        final isConfigError = msg.contains('10') ||
            msg.contains('DEVELOPER_ERROR') ||
            msg.contains('ApiException') ||
            msg.contains('providerConfiguration');
        state = state.copyWith(
          isLoading: false,
          error: isConfigError
              ? 'Google Sign-In is not configured for this device. '
                'Please contact support (SHA-1 may need to be registered).'
              : 'Google Sign-In failed. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _friendlyError(e.toString()));
    }
  }

  // ============ LOGOUT ============
  Future<void> logout() async {
    _userSubscription?.cancel();
    try { await UserPresenceService.instance.goOffline(); } catch (_) {}
    try { SubscriptionExpiryService.instance.stop(); } catch (_) {}
    try {
      final userId = _authRepo.currentUser?.uid;
      if (userId != null) {
        await _userRepo.clearFcmToken(userId);
      }
    } catch (_) {}
    await _authRepo.logout();
    await _clearSavedCredentials();
    state = AuthState.unauthenticated();
  }

  // ============ CHECK AUTH STATE ============
  Future<void> checkAuthState() async {
    // If already authenticated by the authStateChanges listener, skip
    if (state.isAuthenticated) {
      debugPrint('[AUTH] Already authenticated, skipping check');
      return;
    }

    try {
      // Check Firebase cached user directly
      final user = _authRepo.currentUser;
      debugPrint('[AUTH] currentUser: ${user?.uid ?? "NULL"}');

      if (user != null) {
        await _authenticateUser(user);
        return;
      }

      // Wait for authStateChanges to fire (Completer-based, up to 6s).
      // Firebase can take 4-5s on slow/cold-start devices to restore its
      // persisted session from disk — resolves as soon as the stream fires.
      _authReadyCompleter = Completer<void>();
      try {
        await _authReadyCompleter!.future
            .timeout(const Duration(seconds: 6));
      } on TimeoutException {
        debugPrint('[AUTH] authStateChanges did not fire within 6s');
      }

      // Check if the stream listener authenticated us during the wait
      if (state.isAuthenticated) {
        debugPrint('[AUTH] Authenticated via stream listener during wait');
        return;
      }

      // Double-check currentUser (may have become available)
      final retryUser = _authRepo.currentUser;
      if (retryUser != null) {
        debugPrint('[AUTH] currentUser available after wait');
        await _authenticateUser(retryUser);
        return;
      }

      // Try silent re-auth from saved credentials
      final savedMethod = await _getSavedAuthMethod();
      if (savedMethod != null) {
        final reAuthUser = await _attemptSilentReAuth();
        if (reAuthUser != null) {
          await _authenticateUser(reAuthUser);
          return;
        }
        // ONLY clear credentials for email auth (password may have changed)
        // For Google: Firebase handles persistence via its own refresh tokens,
        // so don't clear — a future authStateChanges or app restart may succeed
        if (savedMethod == 'email') {
          debugPrint('[AUTH] Email re-auth failed, clearing saved credentials');
          await _clearSavedCredentials();
        } else {
          debugPrint('[AUTH] Google silent re-auth failed, keeping credentials (Firebase persists Google sessions)');
        }
      }
    } catch (e) {
      debugPrint('[AUTH] checkAuthState ERROR: $e');
    }

    // Nothing worked
    if (!state.isAuthenticated) {
      state = AuthState.unauthenticated();
    }
  }

  /// Shared helper to authenticate a Firebase Auth user
  Future<void> _authenticateUser(User user) async {
    // STEP 1: Try to load full profile from Firestore
    UserModel? userModel;
    try {
      userModel = await _userRepo
          .getUser(user.uid)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[AUTH] ⚠️ Firestore profile load failed: $e');
    }

    // STEP 2: Block suspended or deactivated accounts
    if (userModel != null) {
      if (userModel.status.isSuspended) {
        await _authRepo.logout();
        await _clearSavedCredentials();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            error: 'Your account has been suspended. Please contact admin.',
          );
        }
        debugPrint('[AUTH] ❌ Login blocked — account suspended');
        return;
      }
      if (userModel.status == UserStatus.deactivated) {
        await _authRepo.logout();
        await _clearSavedCredentials();
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            error: 'Your account has been deactivated. Please contact admin.',
          );
        }
        debugPrint('[AUTH] ❌ Login blocked — account deactivated');
        return;
      }
    }

    // STEP 3: Build fallback model if Firestore failed (status=pending is safe here,
    // router will redirect pending users to a waiting screen)
    final effectiveModel = userModel ?? UserModel(
      id: user.uid,
      email: user.email ?? '',
      businessName: user.displayName ?? 'My Business',
      phoneNumber: user.phoneNumber ?? '',
      role: UserRole.user,
      status: UserStatus.pending,
      createdAt: DateTime.now(),
    );

    // STEP 4: SET AUTHENTICATED STATE
    if (mounted) {
      state = AuthState.authenticated(effectiveModel);
      debugPrint('[AUTH] ✅ State set to AUTHENTICATED (uid: ${user.uid}, status: ${effectiveModel.status.name})');
    }

    // STEP 5: Side effects — all in try-catch, non-critical
    try { _listenToUserChanges(user.uid); } catch (e) {
      debugPrint('[AUTH] ⚠️ _listenToUserChanges failed: $e');
    }
    try { _onUserAuthenticated(user.uid); } catch (e) {
      debugPrint('[AUTH] ⚠️ _onUserAuthenticated failed: $e');
    }
  }

  // ============ RESET PASSWORD ============
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepo.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: _friendlyError(e.toString()));
    }
  }

  // ============ LISTEN TO USER CHANGES (REALTIME) ============
  void _listenToUserChanges(String userId) {
    _userSubscription?.cancel();
    _userSubscription = _userRepo.getUserStream(userId).listen((userModel) {
      if (userModel != null && state.isAuthenticated && mounted) {
        // If admin suspends or deactivates user while they are logged in → force logout
        if (userModel.status.isSuspended || userModel.status == UserStatus.deactivated) {
          debugPrint('[AUTH] 🚫 User status changed to ${userModel.status.name} — forcing logout');
          logout();
          return;
        }
        state = AuthState.authenticated(userModel);
      }
    });
  }

  // ============ ERROR MESSAGES ============
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password. Try again';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters)';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again';
      case 'network-request-failed':
        return 'No internet connection. Check your network';
      case 'user-disabled':
        return 'This account has been disabled. Contact support';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method';
      default:
        return e.message ?? 'Authentication failed. Please try again';
    }
  }

  /// Clean up raw Firebase error messages
  String _friendlyError(String rawError) {
    // Strip "[firebase_auth/xxx]" prefix if present
    final regex = RegExp(r'\[firebase_auth/[\w-]+\]\s*');
    return rawError.replaceAll(regex, '').trim();
  }

  /// Start presence tracking + subscription expiry check + FCM token
  void _onUserAuthenticated(String userId) {
    UserPresenceService.instance.goOnline(userId);
    SubscriptionExpiryService.instance.startPeriodicCheck(userId);
    _saveFcmToken(userId);
  }

  /// Save FCM token to Firestore for push notifications
  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token != null) {
        await _userRepo.updateFcmToken(userId, token);
      }
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _userRepo.updateFcmToken(userId, newToken);
      });
    } catch (_) {
      // Non-critical — app works without push notifications
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _userSubscription?.cancel();
    try { UserPresenceService.instance.goOffline(); } catch (_) {}
    try { SubscriptionExpiryService.instance.stop(); } catch (_) {}
    super.dispose();
  }
}
