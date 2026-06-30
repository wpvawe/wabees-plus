import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/bot/bot_model.dart';

/// 🤖 BOT REPOSITORY
class BotRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;

  CollectionReference<Map<String, dynamic>> _bots(String userId) =>
      _firestore.user(userId).collection('bots');

  // ============ REALTIME LIST ============
  Stream<List<BotModel>> getBots(String userId) {
    return _bots(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BotModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET ACTIVE BOTS ============
  Stream<List<BotModel>> getActiveBots(String userId) {
    return _bots(userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BotModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  // ============ GET SINGLE ============
  Future<BotModel?> getBot(String userId, String botId) async {
    final doc = await _bots(userId).doc(botId).get();
    if (!doc.exists) return null;
    return BotModel.fromJson(doc.data()!, doc.id);
  }

  // ============ CREATE ============
  Future<BotModel> createBot(String userId, BotModel bot) async {
    final ref = _bots(userId).doc();
    final newBot = bot.copyWith(id: ref.id, createdAt: DateTime.now());
    await ref.set(newBot.toJson());

    // Increment totalBots on user doc and then repair from source of truth
    try {
      await _firestore.user(userId).update({
        'totalBots': FieldValue.increment(1),
      });
      await _repairTotalBots(userId);
    } catch (_) {}

    return newBot;
  }

  // ============ UPDATE ============
  Future<void> updateBot(String userId, BotModel bot) async {
    await _bots(userId).doc(bot.id).update({
      ...bot.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ TOGGLE ACTIVE ============
  Future<void> toggleActive(String userId, String botId, bool isActive) async {
    await _bots(userId).doc(botId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ DELETE ============
  Future<void> deleteBot(String userId, String botId) async {
    await _bots(userId).doc(botId).delete();

    // Decrement and then repair to avoid negative/incorrect counts
    try {
      await _firestore.user(userId).update({
        'totalBots': FieldValue.increment(-1),
      });
      await _repairTotalBots(userId);
    } catch (_) {}
  }

  // ============ INCREMENT TRIGGER COUNT ============
  Future<void> incrementTriggerCount(String userId, String botId) async {
    await _bots(userId).doc(botId).update({
      'totalTriggered': FieldValue.increment(1),
    });
  }

  // ============ REPAIR TOTAL BOTS ============
  Future<void> _repairTotalBots(String userId) async {
    try {
      final snap = await _bots(userId).get();
      final count = snap.docs.length;
      await _firestore.user(userId).set({'totalBots': count}, SetOptions(merge: true));
    } catch (_) {}
  }
}
