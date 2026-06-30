import '../data/datasources/firebase/firestore_ds.dart';

/// 🛡️ ANTI-BAN SERVICE — Messaging Tier Tracking
/// 
/// Lightweight service — no rate limiting for manual or campaign messages.
/// Only tracks WhatsApp Business API messaging tiers and provides tips.
class AntiBanService {
  final FirestoreDs _firestore = FirestoreDs.instance;

  /// Check if a message can be sent. Always returns null (no limits).
  String? canSend({
    required String contactPhone,
    required String messageText,
  }) {
    return null; // No rate limiting — unlimited messaging
  }

  /// Record a successful send (no-op — no tracking needed)
  void recordSend({
    required String contactPhone,
    required String messageText,
  }) {}

  /// Clear in-memory counters (e.g., on logout or user switch)
  void reset() {}

  /// Get user's messaging tier from Firestore
  Future<Map<String, dynamic>> getMessagingLimits(String userId) async {
    try {
      final userDoc = await _firestore.user(userId).get();
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      
      final totalMessages = data['totalMessages'] ?? 0;
      
      // WhatsApp Business API tiers
      String tier;
      int limit;
      if (totalMessages < 250) {
        tier = 'Starter';
        limit = 250;
      } else if (totalMessages < 1000) {
        tier = 'Tier 1';
        limit = 1000;
      } else if (totalMessages < 10000) {
        tier = 'Tier 2';
        limit = 10000;
      } else if (totalMessages < 100000) {
        tier = 'Tier 3';
        limit = 100000;
      } else {
        tier = 'Unlimited';
        limit = -1;
      }

      return {
        'tier': tier,
        'limit': limit,
        'used': totalMessages,
        'remaining': limit == -1 ? -1 : (limit - totalMessages),
        'percentage': limit == -1 ? 0.0 : (totalMessages / limit * 100).clamp(0.0, 100.0),
      };
    } catch (_) {
      return {
        'tier': 'Unknown',
        'limit': 250,
        'used': 0,
        'remaining': 250,
        'percentage': 0.0,
      };
    }
  }

  /// Check if template should be used (24-hour conversation window)
  bool shouldUseTemplate({
    required DateTime? lastContactActivity,
  }) {
    if (lastContactActivity == null) return true;
    
    final hoursSince = DateTime.now().difference(lastContactActivity).inHours;
    return hoursSince >= 24;
  }

  /// Get anti-ban tips
  static List<String> get tips => [
    '💡 Use templates for first-time messages',
    '💡 Keep messages personalized',
    '💡 Reply to customer messages within 24 hours',
    '💡 Avoid sending to invalid/inactive numbers',
  ];
}
