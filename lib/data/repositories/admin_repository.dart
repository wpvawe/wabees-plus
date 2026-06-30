import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/user/user_model.dart';

/// 🛡️ ADMIN REPOSITORY — User management + platform stats + presence
class AdminRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;

  // ============ ALL USERS (REALTIME) ============
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.allUsers.snapshots().map((snap) =>
        snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // ============ PENDING USERS ============
  Stream<List<UserModel>> getPendingUsers() {
    return _firestore.pendingUsers.snapshots().map((snap) =>
        snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // ============ ONLINE USERS (REALTIME) ============
  Stream<List<UserModel>> getOnlineUsers() {
    return _firestore.users
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // ============ ONLINE COUNT (REALTIME) ============
  Stream<int> watchOnlineCount() {
    return _firestore.users
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============ UPDATE USER STATUS ============
  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.user(userId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ UPDATE USER ROLE ============
  Future<void> updateUserRole(String userId, String role) async {
    await _firestore.user(userId).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ GET SINGLE USER ============
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.user(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ============ PLATFORM STATS (REALTIME STREAM) ============
  Stream<Map<String, int>> watchPlatformStats() {
    return _firestore.users.snapshots().map((allSnap) {
      final users =
          allSnap.docs.map((d) => UserModel.fromFirestore(d)).toList();

      int totalUsers = users.length;
      int activeUsers = users.where((u) => u.status.isActive).length;
      int pendingUsers = users.where((u) => u.status.isPending).length;
      int suspendedUsers = users.where((u) => u.status.isSuspended).length;
      int totalMessages = 0;
      int totalContacts = 0;
      int totalCampaigns = 0;
      int connectedUsers = 0;
      int onlineUsers = 0;

      for (final u in users) {
        totalMessages += u.totalMessages;
        totalContacts += u.totalContacts;
        totalCampaigns += u.totalCampaigns;
        if (u.whatsappConnected) connectedUsers++;
        if (u.isOnline) onlineUsers++;
      }

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'pendingUsers': pendingUsers,
        'suspendedUsers': suspendedUsers,
        'totalMessages': totalMessages,
        'totalContacts': totalContacts,
        'totalCampaigns': totalCampaigns,
        'connectedUsers': connectedUsers,
        'onlineUsers': onlineUsers,
      };
    });
  }

  // ============ PLATFORM STATS (ONE-TIME) ============
  Future<Map<String, int>> getPlatformStats() async {
    final allSnap = await _firestore.users.get();
    final users =
        allSnap.docs.map((d) => UserModel.fromFirestore(d)).toList();

    int totalUsers = users.length;
    int activeUsers = users.where((u) => u.status.isActive).length;
    int pendingUsers = users.where((u) => u.status.isPending).length;
    int suspendedUsers = users.where((u) => u.status.isSuspended).length;
    int totalMessages = 0;
    int totalContacts = 0;
    int totalCampaigns = 0;
    int connectedUsers = 0;

    for (final u in users) {
      totalMessages += u.totalMessages;
      totalContacts += u.totalContacts;
      totalCampaigns += u.totalCampaigns;
      if (u.whatsappConnected) connectedUsers++;
    }

    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'pendingUsers': pendingUsers,
      'suspendedUsers': suspendedUsers,
      'totalMessages': totalMessages,
      'totalContacts': totalContacts,
      'totalCampaigns': totalCampaigns,
      'connectedUsers': connectedUsers,
    };
  }
}
