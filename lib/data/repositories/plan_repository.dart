import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../models/plan/plan_model.dart';
import '../models/plan/subscription_model.dart';
import '../models/notification/app_notification_model.dart';
import '../../core/utils/constants/firestore_paths.dart';
import 'package:dio/dio.dart';

/// 💎 PLAN REPOSITORY — Full plan management with upgrade merge logic
/// Convention: 0 = unlimited for all limit fields
class PlanRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.plans as CollectionReference<Map<String, dynamic>>;

  DocumentReference<Map<String, dynamic>> _subscription(String userId) =>
      _firestore.user(userId).collection('subscription').doc('current');

  CollectionReference<Map<String, dynamic>> get _pendingSubs =>
      _db.collection(FirestorePaths.pendingSubscriptions);

  // ================================================================
  // PLANS (GLOBAL)
  // ================================================================

  /// Get all active plans
  Stream<List<PlanModel>> getPlans() {
    return _plans
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PlanModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Get all plans (admin view, includes inactive)
  Stream<List<PlanModel>> getAllPlans() {
    return _plans
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PlanModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Create plan (admin)
  Future<PlanModel> createPlan(PlanModel plan) async {
    final ref = _plans.doc();
    final newPlan = plan.copyWith(id: ref.id, createdAt: DateTime.now());
    await ref.set(newPlan.toJson());
    return newPlan;
  }

  /// Update plan (admin)
  Future<void> updatePlan(PlanModel plan) async {
    await _plans.doc(plan.id).update(plan.toJson());
  }

  /// Toggle plan active (admin)
  Future<void> togglePlanActive(String planId, bool isActive) async {
    await _plans.doc(planId).update({'isActive': isActive});
  }

  /// Delete plan (admin) — cannot delete welcome plan
  Future<void> deletePlan(String planId) async {
    final doc = await _plans.doc(planId).get();
    if (doc.exists && doc.data()?['isWelcomePlan'] == true) {
      throw Exception('Cannot delete the Welcome plan');
    }
    await _plans.doc(planId).delete();
  }

  // ================================================================
  // WELCOME PLAN
  // ================================================================

  /// Ensure welcome plan exists (called on admin first login or app init)
  Future<PlanModel> ensureWelcomePlan() async {
    // Check if welcome plan already exists
    final existing = await _plans
        .where('isWelcomePlan', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return PlanModel.fromJson(existing.docs.first.data(), existing.docs.first.id);
    }

    // Create welcome plan
    final welcome = PlanModel.welcomePlan();
    final ref = _plans.doc('welcome_plan');
    await ref.set(welcome.toJson());
    return welcome.copyWith(id: ref.id);
  }

  /// Auto-assign welcome plan to new user
  Future<void> assignWelcomePlan(String userId) async {
    final welcomePlan = await ensureWelcomePlan();

    final now = DateTime.now();
    final sub = SubscriptionModel(
      id: 'current',
      planId: welcomePlan.id,
      planName: welcomePlan.name,
      status: 'active',
      maxMessages: welcomePlan.maxMessages,
      maxContacts: welcomePlan.maxContacts,
      maxCampaigns: welcomePlan.maxCampaigns,
      maxBots: welcomePlan.maxBots,
      maxTemplates: welcomePlan.maxTemplates,
      maxAiMessages: welcomePlan.maxAiMessages,
      expiryType: welcomePlan.expiryType,
      expiryDays: welcomePlan.expiryDays,
      startDate: now,
      endDate: welcomePlan.isLifetime ? null : now.add(Duration(days: welcomePlan.expiryDays)),
      createdAt: now,
    );
    await _subscription(userId).set(sub.toJson());

    // Set AI bot monthly limit from welcome plan
    await _db.collection('users').doc(userId)
        .collection('bot_usage').doc('current')
        .set({'monthlyLimit': welcomePlan.maxAiMessages}, SetOptions(merge: true));
  }

  // ================================================================
  // SUBSCRIPTION
  // ================================================================

  /// Get user's current subscription
  Stream<SubscriptionModel?> getSubscription(String userId) {
    return _subscription(userId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SubscriptionModel.fromJson(snap.data()!, snap.id);
    });
  }

  /// Get subscription once (non-stream)
  Future<SubscriptionModel?> getSubscriptionOnce(String userId) async {
    final snap = await _subscription(userId).get();
    if (!snap.exists || snap.data() == null) return null;
    return SubscriptionModel.fromJson(snap.data()!, snap.id);
  }

  /// Sync subscription limits from plan document.
  /// Call on app start to fix existing users whose subscription
  /// was activated before AI message sync was implemented.
  Future<void> syncSubscriptionLimits(String userId) async {
    try {
      final sub = await getSubscriptionOnce(userId);
      if (sub == null || sub.planId.isEmpty) return;

      final planDoc = await _plans.doc(sub.planId).get();
      if (!planDoc.exists) return;

      final planAiMessages = planDoc.data()?['maxAiMessages'] ?? 300;

      // Only update if plan's AI messages differ from subscription
      if (planAiMessages != sub.maxAiMessages) {
        debugPrint('[Sync] Updating AI limit: ${sub.maxAiMessages} → $planAiMessages');
        await _subscription(userId).update({
          'maxAiMessages': planAiMessages,
        });

        // Also sync bot_usage for webhook
        await _db.collection('users').doc(userId)
            .collection('bot_usage').doc('current')
            .set({'monthlyLimit': planAiMessages}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('syncSubscriptionLimits error: $e');
    }
  }

  // ================================================================
  // REQUEST SUBSCRIPTION (User → Pending → Admin activates)
  // ================================================================

  /// User requests a plan upgrade (status = pending)
  /// IMPORTANT: Does NOT overwrite the current subscription.
  /// The pending request is stored separately; dashboard shows old plan until admin approves.
  Future<void> requestSubscription(String userId, PlanModel plan) async {
    final currentSub = await getSubscriptionOnce(userId);
    final now = DateTime.now();

    // Fetch user info to store in pending doc (so admin can identify user)
    String userName = '';
    String userEmail = '';
    String userPhone = '';
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      userName = userData['businessName'] ?? userData['name'] ?? '';
      userEmail = userData['email'] ?? '';
      userPhone = userData['phoneNumber'] ?? userData['phone'] ?? '';
    } catch (_) {}

    // Build pending subscription data (stored in pending_subscriptions ONLY)
    final pendingData = SubscriptionModel(
      id: 'current',
      planId: plan.id,
      planName: plan.name,
      status: 'pending',
      messagesUsed: currentSub?.messagesUsed ?? 0,
      contactsUsed: currentSub?.contactsUsed ?? 0,
      campaignsUsed: currentSub?.campaignsUsed ?? 0,
      botsUsed: currentSub?.botsUsed ?? 0,
      templatesUsed: currentSub?.templatesUsed ?? 0,
      aiMessagesUsed: currentSub?.aiMessagesUsed ?? 0,
      maxMessages: plan.maxMessages,
      maxContacts: plan.maxContacts,
      maxCampaigns: plan.maxCampaigns,
      maxBots: plan.maxBots,
      maxTemplates: plan.maxTemplates,
      maxAiMessages: plan.maxAiMessages,
      expiryType: plan.expiryType,
      expiryDays: plan.expiryDays,
      startDate: now,
      endDate: plan.isLifetime ? null : now.add(Duration(days: plan.expiryDays)),
      createdAt: now,
    );

    // Store pending request in central list (admin sees this) — include user info
    await _pendingSubs.doc(userId).set({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'subscription': pendingData.toJson(),
      'requestedAt': Timestamp.fromDate(now),
    });

    // Mark current subscription with pending info (for UI badge) — but keep old limits!
    await _subscription(userId).set({
      'pendingPlanId': plan.id,
      'pendingPlanName': plan.name,
    }, SetOptions(merge: true));

    // Create admin notification
    await _db.collection('admin_notifications').add(AppNotificationModel(
      id: '',
      title: 'Plan Request',
      body: 'User requested ${plan.name} plan activation',
      type: 'plan_request',
      data: {'userId': userId, 'planId': plan.id, 'planName': plan.name},
      createdAt: DateTime.now(),
    ).toJson());

    // Also send push to admins via backend so it arrives in background
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.wabees.live',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      await dio.post('/notify_admin.php', data: {
        'type': 'plan_request',
        'title': 'Plan Request',
        'body': 'User requested ${plan.name} plan activation',
      });
    } catch (_) {}

    // ── AUTO-REPLY in support chat with package details & payment info ──
    try {
      await _sendPackageAutoReply(userId, plan);
    } catch (e) {
      debugPrint('Auto-reply failed: $e');
    }
  }


  /// Sends a detailed auto-reply in the support chat with package info,
  /// 50% discount pricing, bank details, and payment instructions.
  Future<void> _sendPackageAutoReply(String userId, PlanModel plan) async {
    final chatRef = _db.collection('support_chats').doc(userId);
    final msgRef = chatRef.collection('messages').doc();

    // Calculate 50% discount
    final originalPrice = plan.priceMonthly;
    final discountedPrice = (originalPrice / 2).ceil();
    String limitLabel(int v) => v == 0 ? 'Unlimited' : '$v';

    // Build features list
    final features = <String>[];
    features.add('📨 Messages: ${limitLabel(plan.maxMessages)}');
    features.add('👥 Contacts: ${limitLabel(plan.maxContacts)}');
    features.add('🤖 Bots: ${limitLabel(plan.maxBots)}');
    features.add('📋 Templates: ${limitLabel(plan.maxTemplates)}');
    features.add('📢 Campaigns: ${limitLabel(plan.maxCampaigns)}');
    features.add('🧠 AI Messages: ${limitLabel(plan.maxAiMessages)}');
    if (plan.hasAnalytics) features.add('📊 Analytics');
    if (plan.hasPrioritySupport) features.add('⭐ Priority Support');
    if (plan.hasApiAccess) features.add('🔗 API Access');
    features.add('⏱ Duration: ${plan.expiryLabel}');

    final body = '🎉 ${plan.name} Plan — Request Received!\n\n'
        'Thank you for choosing the ${plan.name} plan! Here are your plan details:\n\n'
        '${features.join('\n')}\n\n'
        '💰 Pricing (50% OFF — Launch Promotion!)\n'
        'Original: ${plan.currency} ${originalPrice.toStringAsFixed(0)}\n'
        '✅ Discounted: ${plan.currency} $discountedPrice only!\n\n'
        '🏦 Payment Details:\n'
        '• Bank: UBL Bank\n'
        '• Title: Abdul Rauf\n'
        '• A/C No: 314386489\n\n'
        '📲 How to Activate:\n'
        '1️⃣ Payment karen above bank account mein\n'
        '2️⃣ Payment ka screenshot yahan support chat mein bhejen\n'
        '   YA hamare WhatsApp pe bhejen: +923003522143\n'
        '3️⃣ Payment confirm hote hi aapka package usi waqt activate ho jayega! ✅\n\n'
        'Aapko package activation ki notification bhi milegi.\n'
        'Koi bhi sawal ho to yahan puch sakte hain! 😊';

    await msgRef.set({
      'senderId': 'system',
      'senderRole': 'admin',
      'body': body,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update chat metadata (include userName so admin can see it)
    // Fetch user name for chat doc
    String userName = '';
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      userName = userDoc.data()?['businessName'] ?? userDoc.data()?['name'] ?? '';
    } catch (_) {}

    await chatRef.set({
      'userId': userId,
      'userName': userName,
      'lastMessage': '🎉 ${plan.name} Plan — Payment Details',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCountUser': FieldValue.increment(1),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ================================================================
  // ADMIN: ACTIVATE / REJECT SUBSCRIPTION
  // ================================================================

  /// Admin activates pending subscription
  /// Reads pending request from pending_subscriptions, builds new sub with fresh plan limits,
  /// replaces the current subscription completely, and syncs bot_usage for webhook.
  Future<void> activateSubscription(String userId) async {
    final now = DateTime.now();

    // 1. Read the pending request (contains the plan the user requested)
    final pendingDoc = await _pendingSubs.doc(userId).get();
    final currentSub = await getSubscriptionOnce(userId);

    // Get pending plan info
    String pendingPlanId;

    if (pendingDoc.exists) {
      final pendingSubData = pendingDoc.data()?['subscription'] as Map<String, dynamic>?;
      pendingPlanId = pendingSubData?['planId'] ?? currentSub?.planId ?? '';
    } else {
      // Fallback: check pendingPlanId on current sub
      pendingPlanId = currentSub?.planId ?? '';
    }

    if (pendingPlanId.isEmpty) return;

    // 2. Read fresh plan limits from the plan document
    final planDoc = await _plans.doc(pendingPlanId).get();
    if (!planDoc.exists) return;

    final planData = planDoc.data()!;
    final plan = PlanModel.fromJson(planData, planDoc.id);

    // 3. Build new subscription with fresh plan limits
    final days = plan.expiryType == 'yearly'
        ? (plan.expiryDays <= 0 ? 365 : plan.expiryDays)
        : plan.expiryDays;

    final newSub = SubscriptionModel(
      id: 'current',
      planId: plan.id,
      planName: plan.name,
      status: 'active',
      messagesUsed: 0,
      contactsUsed: currentSub?.contactsUsed ?? 0,
      campaignsUsed: currentSub?.campaignsUsed ?? 0,
      botsUsed: currentSub?.botsUsed ?? 0,
      templatesUsed: currentSub?.templatesUsed ?? 0,
      aiMessagesUsed: 0,
      maxMessages: plan.maxMessages,
      maxContacts: plan.maxContacts,
      maxCampaigns: plan.maxCampaigns,
      maxBots: plan.maxBots,
      maxTemplates: plan.maxTemplates,
      maxAiMessages: plan.maxAiMessages,
      expiryType: plan.expiryType,
      expiryDays: plan.expiryDays,
      startDate: now,
      endDate: plan.isLifetime ? null : now.add(Duration(days: days)),
      activatedAt: now,
      createdAt: now,
    );

    // 4. Write the complete new subscription (replaces old one entirely)
    await _subscription(userId).set(newSub.toJson());

    // 5. Remove from central pending list
    await _pendingSubs.doc(userId).delete();

    // 6. Notify user
    await _db.collection('users').doc(userId).collection('notifications').add(
      AppNotificationModel(
        id: '',
        title: 'Plan Activated! ✅',
        body: 'Your ${plan.name} plan is now active.',
        type: 'plan_activated',
        data: {'planId': plan.id},
        createdAt: DateTime.now(),
      ).toJson(),
    );

    // 7. Sync AI bot monthly limit + reset usage in bot_usage doc (webhook reads from here)
    await _db.collection('users').doc(userId)
        .collection('bot_usage').doc('current')
        .set({
          'monthlyLimit': plan.maxAiMessages,
          'usedThisMonth': 0,
          'currentPeriodStart': '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
        }, SetOptions(merge: true));
  }

  /// Admin rejects pending subscription
  Future<void> rejectSubscription(String userId) async {
    // Read pending plan name for notification
    final pendingDoc = await _pendingSubs.doc(userId).get();
    final pendingSubData = pendingDoc.data()?['subscription'] as Map<String, dynamic>?;
    final pendingPlanName = pendingSubData?['planName'] ?? 'plan';

    // Clear pending markers from current subscription (keep old plan active)
    await _subscription(userId).update({
      'pendingPlanId': FieldValue.delete(),
      'pendingPlanName': FieldValue.delete(),
    });

    // Remove from central pending list
    await _pendingSubs.doc(userId).delete();

    // Notify user
    await _db.collection('users').doc(userId).collection('notifications').add(
      AppNotificationModel(
        id: '',
        title: 'Plan Request Rejected',
        body: 'Your $pendingPlanName request was not approved. You can contact admin for details.',
        type: 'plan_rejected',
        data: {},
        createdAt: DateTime.now(),
      ).toJson(),
    );
  }

  // ================================================================
  // UPGRADE WITH MERGE LOGIC
  // ================================================================

  /// Upgrade plan with merge rules:
  /// - Messages: remaining_old + max_new (ADD)
  /// - Contacts/Bots/Templates/Campaigns: max(old, new) (TAKE MAX)
  /// - If new is 0 → unlimited (always wins)
  Future<void> upgradePlan(String userId, PlanModel newPlan) async {
    final oldSub = await getSubscriptionOnce(userId);
    final now = DateTime.now();

    int mergeMessages;
    if (newPlan.maxMessages == 0) {
      mergeMessages = 0; // unlimited
    } else if (oldSub != null && oldSub.maxMessages == 0) {
      mergeMessages = 0; // was unlimited, stays unlimited
    } else {
      final remaining = oldSub != null ? (oldSub.maxMessages - oldSub.messagesUsed).clamp(0, oldSub.maxMessages) : 0;
      mergeMessages = remaining + newPlan.maxMessages;
    }

    // AI messages merge: same ADD logic as regular messages
    int mergeAiMessages;
    if (newPlan.maxAiMessages == 0) {
      mergeAiMessages = 0; // unlimited
    } else if (oldSub != null && oldSub.maxAiMessages == 0) {
      mergeAiMessages = 0; // was unlimited, stays unlimited
    } else {
      final aiRemaining = oldSub != null ? (oldSub.maxAiMessages - oldSub.aiMessagesUsed).clamp(0, oldSub.maxAiMessages) : 0;
      mergeAiMessages = aiRemaining + newPlan.maxAiMessages;
    }

    int mergeLimit(int oldMax, int newMax) {
      if (newMax == 0 || oldMax == 0) return 0; // unlimited wins
      return max(oldMax, newMax);
    }

    final sub = SubscriptionModel(
      id: 'current',
      planId: newPlan.id,
      planName: newPlan.name,
      status: 'active',
      messagesUsed: oldSub?.messagesUsed ?? 0,
      contactsUsed: oldSub?.contactsUsed ?? 0,
      campaignsUsed: oldSub?.campaignsUsed ?? 0,
      botsUsed: oldSub?.botsUsed ?? 0,
      templatesUsed: oldSub?.templatesUsed ?? 0,
      aiMessagesUsed: oldSub?.aiMessagesUsed ?? 0,
      maxMessages: mergeMessages,
      maxContacts: mergeLimit(oldSub?.maxContacts ?? 0, newPlan.maxContacts),
      maxCampaigns: mergeLimit(oldSub?.maxCampaigns ?? 0, newPlan.maxCampaigns),
      maxBots: mergeLimit(oldSub?.maxBots ?? 0, newPlan.maxBots),
      maxTemplates: mergeLimit(oldSub?.maxTemplates ?? 0, newPlan.maxTemplates),
      maxAiMessages: mergeAiMessages,
      expiryType: newPlan.expiryType,
      expiryDays: newPlan.expiryDays,
      startDate: now,
      endDate: newPlan.isLifetime ? null : now.add(Duration(days: newPlan.expiryDays)),
      activatedAt: now,
      createdAt: now,
    );
    await _subscription(userId).set(sub.toJson());

    // Sync AI bot monthly limit + reset webhook usage counter
    final now2 = DateTime.now();
    await _db.collection('users').doc(userId)
        .collection('bot_usage').doc('current')
        .set({
          'monthlyLimit': newPlan.maxAiMessages,
          'usedThisMonth': 0,
          'currentPeriodStart': '${now2.year}-${now2.month.toString().padLeft(2, '0')}-01',
        }, SetOptions(merge: true));
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String userId) async {
    await _subscription(userId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // ================================================================
  // USAGE TRACKING
  // ================================================================

  Future<void> incrementMessages(String userId, {int count = 1}) async {
    await _subscription(userId).update({
      'messagesUsed': FieldValue.increment(count),
    });
  }

  Future<void> incrementContacts(String userId, {int count = 1}) async {
    await _subscription(userId).update({
      'contactsUsed': FieldValue.increment(count),
    });
  }

  Future<void> incrementCampaigns(String userId, {int count = 1}) async {
    await _subscription(userId).update({
      'campaignsUsed': FieldValue.increment(count),
    });
  }

  Future<void> incrementTemplates(String userId, {int count = 1}) async {
    await _subscription(userId).update({
      'templatesUsed': FieldValue.increment(count),
    });
  }

  Future<void> incrementAiMessages(String userId, {int count = 1}) async {
    await _subscription(userId).update({
      'aiMessagesUsed': FieldValue.increment(count),
    });
  }

  // ================================================================
  // ADMIN: GET ALL PENDING SUBSCRIPTIONS
  // ================================================================
  Stream<List<Map<String, dynamic>>> getPendingSubscriptions() {
    return _pendingSubs
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        // Parse requestedAt timestamp
        DateTime? requestedAt;
        try {
          final ts = data['requestedAt'];
          if (ts is Timestamp) requestedAt = ts.toDate();
        } catch (_) {}

        return {
          'userId': data['userId'] ?? '',
          'userName': data['userName'] ?? '',
          'userEmail': data['userEmail'] ?? '',
          'userPhone': data['userPhone'] ?? '',
          'requestedAt': requestedAt,
          'subscription': SubscriptionModel.fromJson(data['subscription'] ?? {}, doc.id),
        };
      }).toList();
    });
  }
}
