import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../plans/plan_provider.dart';

// ============ AI BOT CONFIG MODEL ============
class AiBotConfig {
  final bool enabled;
  final String businessName;
  final String businessType;
  final String services;
  final String timings;
  final String location;
  final String contacts;
  final String customInfo;
  final String faq;
  final String customInstructions;
  final String tone;
  final String greeting;
  final String handoffKeywords;
  final String leadFields;
  final String afterHoursMessage;

  const AiBotConfig({
    this.enabled = false,
    this.businessName = '',
    this.businessType = '',
    this.services = '',
    this.timings = '',
    this.location = '',
    this.contacts = '',
    this.customInfo = '',
    this.faq = '[]',
    this.customInstructions = '',
    this.tone = 'professional',
    this.greeting = '',
    this.handoffKeywords = '',
    this.leadFields = 'name,phone,email',
    this.afterHoursMessage = '',
  });

  factory AiBotConfig.fromFirestore(Map<String, dynamic> data) {
    return AiBotConfig(
      enabled: data['enabled'] ?? false,
      businessName: data['businessName'] ?? '',
      businessType: data['businessType'] ?? '',
      services: data['services'] ?? '',
      timings: data['timings'] ?? '',
      location: data['location'] ?? '',
      contacts: data['contacts'] ?? '',
      customInfo: data['customInfo'] ?? '',
      faq: data['faq'] ?? '[]',
      customInstructions: data['customInstructions'] ?? '',
      tone: data['tone'] ?? 'professional',
      greeting: data['greeting'] ?? '',
      handoffKeywords: data['handoffKeywords'] ?? '',
      leadFields: data['leadFields'] ?? 'name,phone,email',
      afterHoursMessage: data['afterHoursMessage'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'enabled': enabled,
    'businessName': businessName,
    'businessType': businessType,
    'services': services,
    'timings': timings,
    'location': location,
    'contacts': contacts,
    'customInfo': customInfo,
    'faq': faq,
    'customInstructions': customInstructions,
    'tone': tone,
    'greeting': greeting,
    'handoffKeywords': handoffKeywords,
    'leadFields': leadFields,
    'afterHoursMessage': afterHoursMessage,
  };
}

// ============ AI BOT USAGE MODEL ============
class AiBotUsage {
  final String plan;
  final int usedThisMonth;
  final int monthlyLimit;
  final String currentPeriodStart;

  const AiBotUsage({
    this.plan = 'free',
    this.usedThisMonth = 0,
    this.monthlyLimit = 300,
    this.currentPeriodStart = '',
  });

  factory AiBotUsage.fromFirestore(Map<String, dynamic> data) {
    final plan = data['plan'] ?? 'free';
    final int limit = data['monthlyLimit'] ?? 300;
    return AiBotUsage(
      plan: plan,
      usedThisMonth: data['usedThisMonth'] ?? 0,
      monthlyLimit: limit,
      currentPeriodStart: data['currentPeriodStart'] ?? '',
    );
  }

  /// Create usage with subscription limit override
  AiBotUsage withLimit(int subscriptionLimit) {
    return AiBotUsage(
      plan: plan,
      usedThisMonth: usedThisMonth,
      monthlyLimit: subscriptionLimit,
      currentPeriodStart: currentPeriodStart,
    );
  }

  double get usagePercent =>
      monthlyLimit > 0 ? (usedThisMonth / monthlyLimit).clamp(0.0, 1.0) : 0.0;
  int get remaining => (monthlyLimit - usedThisMonth).clamp(0, monthlyLimit);
}

// ============ AI BOT LEAD MODEL ============
class AiBotLead {
  final String name;
  final String phone;
  final String email;
  final String cnic;
  final String score;
  final String details;
  final int messageCount;
  final String firstContactAt;
  final String lastContactAt;

  const AiBotLead({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.cnic = '',
    this.score = 'cold',
    this.details = '',
    this.messageCount = 0,
    this.firstContactAt = '',
    this.lastContactAt = '',
  });

  factory AiBotLead.fromFirestore(Map<String, dynamic> data) {
    return AiBotLead(
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      cnic: (data['cnic'] ?? '').toString(),
      score: (data['score'] ?? 'cold').toString(),
      details: (data['details'] ?? '').toString(),
      messageCount: (data['messageCount'] is num) ? (data['messageCount'] as num).toInt() : 0,
      firstContactAt: (data['firstContactAt'] ?? '').toString(),
      lastContactAt: (data['lastContactAt'] ?? '').toString(),
    );
  }
}

// ============ PROVIDERS ============
final _db = FirebaseFirestore.instance;

/// Stream AI bot config
final aiBotConfigProvider = StreamProvider<AiBotConfig>((ref) {
  final uid = ref.watch(dataOwnerIdProvider);
  if (uid == null) return Stream.value(const AiBotConfig());
  return _db
      .collection('users')
      .doc(uid)
      .collection('bot_config')
      .doc('settings')
      .snapshots()
      .map((snap) => snap.exists
          ? AiBotConfig.fromFirestore(snap.data()!)
          : const AiBotConfig());
});

/// Stream AI bot usage — merges bot_usage/current (for usedThisMonth) with
/// the subscription's maxAiMessages (the real source of truth for limits).
/// Also auto-syncs bot_usage/current.monthlyLimit if it's out of date.
final aiBotUsageProvider = StreamProvider<AiBotUsage>((ref) {
  final uid = ref.watch(dataOwnerIdProvider);
  if (uid == null) return Stream.value(const AiBotUsage());

  // Get subscription limit (source of truth)
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  final subLimit = sub?.maxAiMessages ?? 300;

  return _db
      .collection('users')
      .doc(uid)
      .collection('bot_usage')
      .doc('current')
      .snapshots()
      .map((snap) {
    if (!snap.exists) {
      // No bot_usage doc yet — create it with subscription limit
      _db.collection('users').doc(uid)
          .collection('bot_usage').doc('current')
          .set({'monthlyLimit': subLimit, 'usedThisMonth': 0}, SetOptions(merge: true))
          .catchError((_) {});
      return AiBotUsage(monthlyLimit: subLimit);
    }

    final usage = AiBotUsage.fromFirestore(snap.data()!);

    // Auto-sync: if subscription limit differs from bot_usage, update bot_usage
    // This fixes existing users whose bot_usage was never synced
    if (usage.monthlyLimit != subLimit && sub != null) {
      debugPrint('[AI Bot] Syncing monthlyLimit: ${usage.monthlyLimit} → $subLimit');
      _db.collection('users').doc(uid)
          .collection('bot_usage').doc('current')
          .update({'monthlyLimit': subLimit})
          .catchError((_) {});
      return usage.withLimit(subLimit);
    }

    return usage;
  });
});

/// Stream AI bot leads
final aiBotLeadsProvider = StreamProvider<List<AiBotLead>>((ref) {
  final uid = ref.watch(dataOwnerIdProvider);
  if (uid == null) return Stream.value([]);
  return _db
      .collection('users')
      .doc(uid)
      .collection('bot_leads') // FIXED: was 'ai_leads' — now matches Firestore security rules
      .orderBy('lastContactAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => AiBotLead.fromFirestore(d.data())).toList());
});

// ============ HELPER FUNCTIONS ============

/// Toggle AI bot on/off
Future<void> toggleAiBot(String userId, bool enabled) async {
  await _db
      .collection('users')
      .doc(userId)
      .collection('bot_config')
      .doc('settings')
      .set({'enabled': enabled}, SetOptions(merge: true));
}

/// Save full AI bot config
Future<void> saveAiBotConfig(String userId, AiBotConfig config) async {
  await _db
      .collection('users')
      .doc(userId)
      .collection('bot_config')
      .doc('settings')
      .set(config.toFirestore(), SetOptions(merge: true));
}
