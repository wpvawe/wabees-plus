import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/firebase/firestore_ds.dart';

/// 🟢 USER PRESENCE SERVICE — Track online/offline status
///
/// Sets user online when app is active, offline on disconnect.
/// Admin can see realtime online user count.
class UserPresenceService {
  UserPresenceService._();
  static final UserPresenceService instance = UserPresenceService._();

  final FirestoreDs _firestore = FirestoreDs.instance;
  Timer? _heartbeatTimer;
  String? _currentUserId;

  /// Set user online + start heartbeat
  Future<void> goOnline(String userId) async {
    _currentUserId = userId;
    try {
      await _firestore.user(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Heartbeat every 2 minutes
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _heartbeat(userId),
      );
    } catch (_) {}
  }

  /// Set user offline
  Future<void> goOffline() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_currentUserId != null) {
      try {
        await _firestore.user(_currentUserId!).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    _currentUserId = null;
  }

  /// Heartbeat — update lastSeen
  Future<void> _heartbeat(String userId) async {
    try {
      await _firestore.user(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// ADMIN: Stream of online users count
  Stream<int> watchOnlineUsersCount() {
    return _firestore.users
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// ADMIN: Stream of online users list
  Stream<List<Map<String, dynamic>>> watchOnlineUsers() {
    return _firestore.users
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'name': data['name'] ?? '',
                'email': data['email'] ?? '',
                'lastSeen': data['lastSeen'],
              };
            }).toList());
  }
}
