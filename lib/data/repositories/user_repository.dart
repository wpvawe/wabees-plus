import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/user/user_model.dart';

/// 👤 USER REPOSITORY
class UserRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;

  // ============ CREATE USER ============
  Future<void> createUser(UserModel user) async {
    await _firestore.user(user.id).set(user.toJson());
  }

  // ============ GET USER ============
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.user(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ============ GET USER STREAM (REALTIME) ============
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.user(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // ============ UPDATE USER ============
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.user(userId).update(data);
  }

  // ============ UPDATE FCM TOKEN ============
  Future<void> updateFcmToken(String userId, String token) async {
    await _firestore.user(userId).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ CLEAR FCM TOKEN ============
  Future<void> clearFcmToken(String userId) async {
    await _firestore.user(userId).update({
      'fcmToken': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ ADMIN: GET ALL USERS (REALTIME) ============
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore.allUsers.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  // ============ ADMIN: GET PENDING USERS ============
  Stream<List<UserModel>> getPendingUsersStream() {
    return _firestore.pendingUsers.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  // ============ ADMIN: UPDATE USER STATUS ============
  Future<void> updateUserStatus(String userId, String status) async {
    await _firestore.user(userId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
