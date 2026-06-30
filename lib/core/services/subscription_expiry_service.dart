import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/firebase/firestore_ds.dart';

/// ⏰ SUBSCRIPTION EXPIRY SERVICE — Auto-expire subscriptions
/// Lifetime plans (expiryType == 'lifetime') never expire.
class SubscriptionExpiryService {
  SubscriptionExpiryService._();
  static final SubscriptionExpiryService instance =
      SubscriptionExpiryService._();

  Timer? _checkTimer;
  final FirestoreDs _firestore = FirestoreDs.instance;

  /// Start periodic expiry check (every 6 hours)
  void startPeriodicCheck(String userId) {
    checkAndExpire(userId);
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => checkAndExpire(userId),
    );
  }

  /// Stop periodic check
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Check and auto-expire if past endDate (skip lifetime plans)
  Future<void> checkAndExpire(String userId) async {
    try {
      final subDoc = _firestore
          .user(userId)
          .collection('subscription')
          .doc('current');

      final snap = await subDoc.get();
      if (!snap.exists) return;

      final data = snap.data();
      if (data == null) return;

      final status = data['status'] as String? ?? '';
      if (status != 'active') return;

      // Lifetime plans never expire
      final expiryType = data['expiryType'] as String? ?? 'monthly';
      if (expiryType == 'lifetime') return;

      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (endDate == null) return;

      if (DateTime.now().isAfter(endDate)) {
        await subDoc.update({
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Silently fail — will retry on next check
    }
  }
}
