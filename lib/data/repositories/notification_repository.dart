import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/notification/app_notification_model.dart';

/// 🔔 NOTIFICATION REPOSITORY — In-app notifications for user and admin
class NotificationRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userNotifications(String userId) =>
      _firestore.user(userId).collection('notifications');

  CollectionReference<Map<String, dynamic>> get _adminNotifications =>
      _db.collection('admin_notifications');

  // ============ USER NOTIFICATIONS (REALTIME) ============
  Stream<List<AppNotificationModel>> getUserNotifications(String userId) {
    return _userNotifications(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotificationModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ ADMIN NOTIFICATIONS (REALTIME) ============
  Stream<List<AppNotificationModel>> getAdminNotifications() {
    return _adminNotifications
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotificationModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ UNREAD COUNT ============
  Stream<int> getUserUnreadCount(String userId) {
    return _userNotifications(userId)
        .where('read', isNotEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> getAdminUnreadCount() {
    return _adminNotifications
        .where('read', isNotEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============ MARK AS READ ============
  Future<void> markAsRead(String userId, String notificationId) async {
    await _userNotifications(userId).doc(notificationId).update({'read': true});
  }

  Future<void> markAdminAsRead(String notificationId) async {
    await _adminNotifications.doc(notificationId).update({'read': true});
  }

  // ============ MARK ALL READ ============
  Future<void> markAllRead(String userId) async {
    final unread = await _userNotifications(userId)
        .where('read', isNotEqualTo: true)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> markAllAdminRead() async {
    final unread = await _adminNotifications
        .where('read', isNotEqualTo: true)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ============ DELETE NOTIFICATION ============
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _userNotifications(userId).doc(notificationId).delete();
  }

  Future<void> deleteAdminNotification(String notificationId) async {
    await _adminNotifications.doc(notificationId).delete();
  }

  // ============ CREATE NOTIFICATION ============
  Future<void> createUserNotification(String userId, AppNotificationModel notification) async {
    await _userNotifications(userId).add(notification.toJson());
  }

  Future<void> createAdminNotification(AppNotificationModel notification) async {
    await _adminNotifications.add(notification.toJson());
  }
}
