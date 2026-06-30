import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/campaign/campaign_model.dart';
import '../models/campaign/campaign_status.dart';

/// 📊 CAMPAIGN REPOSITORY — Full CRUD + Realtime tracking
class CampaignRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;

  CollectionReference<Map<String, dynamic>> _campaigns(String userId) =>
      _firestore.user(userId).collection('campaigns');

  // ============ REALTIME LIST ============
  Stream<List<CampaignModel>> getCampaigns(String userId) {
    return _campaigns(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CampaignModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ REALTIME SINGLE CAMPAIGN (for live tracking) ============
  Stream<CampaignModel?> watchCampaign(String userId, String campaignId) {
    return _campaigns(userId).doc(campaignId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CampaignModel.fromJson(snap.data()!, snap.id);
    });
  }

  // ============ ACTIVE CAMPAIGNS STREAM (running ones) ============
  Stream<List<CampaignModel>> getActiveCampaigns(String userId) {
    return _campaigns(userId)
        .where('status', isEqualTo: 'running')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CampaignModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET SINGLE ============
  Future<CampaignModel?> getCampaign(
      String userId, String campaignId) async {
    final doc = await _campaigns(userId).doc(campaignId).get();
    if (!doc.exists) return null;
    return CampaignModel.fromJson(doc.data()!, doc.id);
  }

  // ============ CREATE ============
  Future<CampaignModel> createCampaign(
      String userId, CampaignModel campaign) async {
    final ref = _campaigns(userId).doc();
    final newCampaign = campaign.copyWith(
      id: ref.id,
      createdAt: DateTime.now(),
      status: CampaignStatus.draft,
    );
    await ref.set(newCampaign.toJson());
    // Increment user's totalCampaigns counter
    await _firestore.user(userId).update({
      'totalCampaigns': FieldValue.increment(1),
    });
    return newCampaign;
  }

  // ============ UPDATE ============
  Future<void> updateCampaign(
      String userId, CampaignModel campaign) async {
    await _campaigns(userId).doc(campaign.id).update(campaign.toJson());
  }

  // ============ DELETE ============
  Future<void> deleteCampaign(String userId, String campaignId) async {
    await _campaigns(userId).doc(campaignId).delete();
    // Decrement user's totalCampaigns counter
    await _firestore.user(userId).update({
      'totalCampaigns': FieldValue.increment(-1),
    });
  }

  // ============ UPDATE STATUS ============
  Future<void> updateStatus(
      String userId, String campaignId, CampaignStatus status) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == CampaignStatus.running) {
      updates['startedAt'] = FieldValue.serverTimestamp();
    } else if (status == CampaignStatus.completed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    await _campaigns(userId).doc(campaignId).update(updates);
  }

  // ============ START CAMPAIGN (set running + track) ============
  Future<void> startCampaign(String userId, String campaignId) async {
    await updateStatus(userId, campaignId, CampaignStatus.running);
  }

  // ============ PAUSE CAMPAIGN ============
  Future<void> pauseCampaign(String userId, String campaignId) async {
    await updateStatus(userId, campaignId, CampaignStatus.paused);
  }

  // ============ RESUME CAMPAIGN ============
  Future<void> resumeCampaign(String userId, String campaignId) async {
    await updateStatus(userId, campaignId, CampaignStatus.running);
  }

  // ============ RESTART CAMPAIGN (reset stats + re-run) ============
  Future<void> restartCampaign(String userId, String campaignId) async {
    await _campaigns(userId).doc(campaignId).update({
      'status': CampaignStatus.running.name,
      'sentCount': 0,
      'deliveredCount': 0,
      'readCount': 0,
      'failedCount': 0,
      'progress': 0,
      'wamidMap': {},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ COMPLETE CAMPAIGN ============
  Future<void> completeCampaign(String userId, String campaignId) async {
    await updateStatus(userId, campaignId, CampaignStatus.completed);

    // Notify user about campaign completion
    final campaignDoc = await _campaigns(userId).doc(campaignId).get();
    final campaignName = campaignDoc.data()?['name'] ?? 'Campaign';
    final sentCount = campaignDoc.data()?['sentCount'] ?? 0;

    await _firestore.user(userId).collection('notifications').add({
      'title': 'Campaign Completed! 🚀',
      'body': '$campaignName finished. $sentCount messages sent.',
      'type': 'campaign_completed',
      'data': {'campaignId': campaignId},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ INCREMENT ANALYTICS (batch-safe) ============
  Future<void> incrementSent(String userId, String campaignId,
      {int count = 1}) async {
    await _campaigns(userId).doc(campaignId).update({
      'sentCount': FieldValue.increment(count),
    });
  }

  Future<void> incrementDelivered(String userId, String campaignId,
      {int count = 1}) async {
    await _campaigns(userId).doc(campaignId).update({
      'deliveredCount': FieldValue.increment(count),
    });
  }

  Future<void> incrementRead(String userId, String campaignId,
      {int count = 1}) async {
    await _campaigns(userId).doc(campaignId).update({
      'readCount': FieldValue.increment(count),
    });
  }

  Future<void> incrementFailed(String userId, String campaignId,
      {int count = 1}) async {
    await _campaigns(userId).doc(campaignId).update({
      'failedCount': FieldValue.increment(count),
    });
  }

  // ============ BATCH UPDATE ANALYTICS ============
  Future<void> updateAnalytics(
    String userId,
    String campaignId, {
    int? sent,
    int? delivered,
    int? read,
    int? failed,
  }) async {
    final updates = <String, dynamic>{};
    if (sent != null) updates['sentCount'] = FieldValue.increment(sent);
    if (delivered != null) {
      updates['deliveredCount'] = FieldValue.increment(delivered);
    }
    if (read != null) updates['readCount'] = FieldValue.increment(read);
    if (failed != null) {
      updates['failedCount'] = FieldValue.increment(failed);
    }
    if (updates.isNotEmpty) {
      await _campaigns(userId).doc(campaignId).update(updates);
    }
  }

  // ============ MESSAGE LOGS ============
  /// Save individual message send result to subcollection
  Future<void> addLog(
    String userId,
    String campaignId, {
    required String phone,
    required String status,
    String? reason,
    String? wamid,
  }) async {
    await _campaigns(userId)
        .doc(campaignId)
        .collection('logs')
        .add({
      'phone': phone,
      'status': status,
      'reason': reason,
      if (wamid != null) 'wamid': wamid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream recent message logs for a campaign (real-time)
  Stream<List<Map<String, dynamic>>> getLogs(
    String userId,
    String campaignId, {
    int limit = 100,
  }) {
    return _campaigns(userId)
        .doc(campaignId)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Get phones that were successfully sent (for resume skip)
  Future<Set<String>> getCompletedPhones(
    String userId,
    String campaignId,
  ) async {
    final snap = await _campaigns(userId)
        .doc(campaignId)
        .collection('logs')
        .where('status', isEqualTo: 'sent')
        .get();
    return snap.docs
        .map((d) => d.data()['phone'] as String? ?? '')
        .toSet();
  }

  /// Get ALL processed phones (sent + failed) — for resume dedup
  Future<Set<String>> getAllProcessedPhones(
    String userId,
    String campaignId,
  ) async {
    final snap = await _campaigns(userId)
        .doc(campaignId)
        .collection('logs')
        .get();
    return snap.docs
        .map((d) => d.data()['phone'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toSet();
  }

  /// Get only failed phones — for auto-retry
  Future<List<String>> getFailedPhones(
    String userId,
    String campaignId,
  ) async {
    final snap = await _campaigns(userId)
        .doc(campaignId)
        .collection('logs')
        .where('status', isEqualTo: 'failed')
        .get();
    return snap.docs
        .map((d) => d.data()['phone'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Decrement failed count (when retry succeeds)
  Future<void> decrementFailed(String userId, String campaignId) async {
    await _campaigns(userId).doc(campaignId).update({
      'failedCount': FieldValue.increment(-1),
    });
  }
}
