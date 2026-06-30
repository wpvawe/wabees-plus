import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/constants/firestore_paths.dart';

/// 📡 FIRESTORE DATA SOURCE - SINGLE INSTANCE
class FirestoreDs {
  FirestoreDs._();
  static final FirestoreDs _instance = FirestoreDs._();
  static FirestoreDs get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ ENABLE OFFLINE PERSISTENCE ============
  Future<void> enablePersistence() async {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ============ USERS ============
  CollectionReference get users => _firestore.collection(FirestorePaths.users);
  DocumentReference user(String id) => users.doc(id);

  // ============ MESSAGES ============
  CollectionReference messages(String userId) =>
      users.doc(userId).collection(FirestorePaths.messages);
  DocumentReference message(String userId, String messageId) =>
      messages(userId).doc(messageId);

  // ============ BOTS ============
  CollectionReference bots(String userId) =>
      users.doc(userId).collection(FirestorePaths.bots);
  DocumentReference bot(String userId, String botId) =>
      bots(userId).doc(botId);

  // ============ CAMPAIGNS ============
  CollectionReference campaigns(String userId) =>
      users.doc(userId).collection(FirestorePaths.campaigns);

  // ============ CONTACTS ============
  CollectionReference contacts(String userId) =>
      users.doc(userId).collection(FirestorePaths.contacts);

  // ============ TEMPLATES ============
  CollectionReference templates(String userId) =>
      users.doc(userId).collection(FirestorePaths.templates);

  // ============ PLANS ============
  CollectionReference get plans => _firestore.collection(FirestorePaths.plans);

  // ============ SUBSCRIPTIONS ============
  CollectionReference subscriptions(String userId) =>
      users.doc(userId).collection(FirestorePaths.subscription);

  // ============ ADMIN QUERIES ============
  Query get allUsers => users.orderBy('createdAt', descending: true);
  Query get pendingUsers => users.where('status', isEqualTo: 'pending');
  Query get activeUsers => users.where('status', isEqualTo: 'active');
  Query get suspendedUsers => users.where('status', isEqualTo: 'suspended');
}
