import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/datasources/firebase/firestore_ds.dart';

/// 🧹 AUTO-CLEANUP SERVICE — Delete old messages to save Firestore space
class CleanupService {
  final FirestoreDs _firestore = FirestoreDs.instance;

  /// Default retention period in days
  static const int defaultRetentionDays = 60;

  /// Run cleanup for a user — deletes messages older than [retentionDays]
  /// Returns the number of deleted messages
  Future<int> cleanupOldMessages({
    required String userId,
    int retentionDays = defaultRetentionDays,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));

    // Query messages older than cutoff
    final query = await _firestore
        .user(userId)
        .collection('messages')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .limit(500) // Batch limit to avoid timeout
        .get();

    if (query.docs.isEmpty) return 0;

    // Delete in batches of 500 (Firestore limit)
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return query.docs.length;
  }

  /// Run cleanup for old conversations with no recent activity
  Future<int> cleanupStaleConversations({
    required String userId,
    int staleDays = 90,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: staleDays));

    final query = await _firestore
        .user(userId)
        .collection('conversations')
        .where('lastMessageAt', isLessThan: Timestamp.fromDate(cutoff))
        .limit(200)
        .get();

    if (query.docs.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return query.docs.length;
  }

  /// Full cleanup — messages + stale conversations
  Future<Map<String, int>> runFullCleanup({
    required String userId,
    int messageRetentionDays = defaultRetentionDays,
    int conversationStaleDays = 90,
  }) async {
    int totalMessages = 0;
    int totalConversations = 0;

    // Run in loops until all old data is deleted
    while (true) {
      final deleted = await cleanupOldMessages(
        userId: userId,
        retentionDays: messageRetentionDays,
      );
      totalMessages += deleted;
      if (deleted < 500) break; // Last batch
    }

    totalConversations = await cleanupStaleConversations(
      userId: userId,
      staleDays: conversationStaleDays,
    );

    // Update user's cleanup timestamp
    await _firestore.user(userId).set({
      'lastCleanupAt': FieldValue.serverTimestamp(),
      'lastCleanupResult': {
        'messagesDeleted': totalMessages,
        'conversationsDeleted': totalConversations,
      },
    }, SetOptions(merge: true));

    return {
      'messages': totalMessages,
      'conversations': totalConversations,
    };
  }

  /// Check if cleanup is needed (not run in last 7 days)
  Future<bool> isCleanupNeeded(String userId) async {
    final doc = await _firestore.user(userId).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final lastCleanup = data['lastCleanupAt'] as Timestamp?;
    if (lastCleanup == null) return true; // Never cleaned

    final daysSince = DateTime.now()
        .difference(lastCleanup.toDate())
        .inDays;

    return daysSince >= 7; // Cleanup every 7 days
  }

  /// Get cleanup stats for display
  Future<Map<String, dynamic>> getCleanupStats(String userId) async {
    final doc = await _firestore.user(userId).get();
    if (!doc.exists) return {};

    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return {
      'lastCleanupAt': (data['lastCleanupAt'] as Timestamp?)?.toDate(),
      'lastResult': data['lastCleanupResult'] as Map<String, dynamic>?,
    };
  }
}
