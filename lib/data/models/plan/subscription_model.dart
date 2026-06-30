import 'package:cloud_firestore/cloud_firestore.dart';

/// 💎 SUBSCRIPTION MODEL — User's active subscription
/// Convention: 0 = unlimited for all limit fields
class SubscriptionModel {
  final String id;
  final String planId;
  final String planName;
  final String status; // active, expired, cancelled, pending

  // Usage tracking
  final int messagesUsed;
  final int contactsUsed;
  final int campaignsUsed;
  final int botsUsed;
  final int templatesUsed;
  final int aiMessagesUsed;

  // Plan limits (copied at subscription time, 0 = unlimited)
  final int maxMessages;
  final int maxContacts;
  final int maxCampaigns;
  final int maxBots;
  final int maxTemplates;
  final int maxAiMessages;

  // Expiry
  final String expiryType; // monthly, yearly, lifetime
  final int expiryDays;

  // Dates
  final DateTime startDate;
  final DateTime? endDate; // null for lifetime
  final DateTime? cancelledAt;
  final DateTime? activatedAt; // when admin activated pending sub
  final DateTime createdAt;

  // Pending upgrade markers (set when user requests, cleared on activate/reject)
  final String? pendingPlanId;
  final String? pendingPlanName;

  const SubscriptionModel({
    required this.id,
    required this.planId,
    required this.planName,
    this.status = 'active',
    this.messagesUsed = 0,
    this.contactsUsed = 0,
    this.campaignsUsed = 0,
    this.botsUsed = 0,
    this.templatesUsed = 0,
    this.aiMessagesUsed = 0,
    this.maxMessages = 1000,
    this.maxContacts = 100,
    this.maxCampaigns = 5,
    this.maxBots = 2,
    this.maxTemplates = 10,
    this.maxAiMessages = 300,
    this.expiryType = 'monthly',
    this.expiryDays = 30,
    required this.startDate,
    this.endDate,
    this.cancelledAt,
    this.activatedAt,
    required this.createdAt,
    this.pendingPlanId,
    this.pendingPlanName,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json, String docId) {
    return SubscriptionModel(
      id: docId,
      planId: json['planId'] ?? '',
      planName: json['planName'] ?? '',
      status: json['status'] ?? 'active',
      messagesUsed: json['messagesUsed'] ?? 0,
      contactsUsed: json['contactsUsed'] ?? 0,
      campaignsUsed: json['campaignsUsed'] ?? 0,
      botsUsed: json['botsUsed'] ?? 0,
      templatesUsed: json['templatesUsed'] ?? 0,
      aiMessagesUsed: json['aiMessagesUsed'] ?? 0,
      maxMessages: json['maxMessages'] ?? 1000,
      maxContacts: json['maxContacts'] ?? 100,
      maxCampaigns: json['maxCampaigns'] ?? 5,
      maxBots: json['maxBots'] ?? 2,
      maxTemplates: json['maxTemplates'] ?? 10,
      maxAiMessages: json['maxAiMessages'] ?? 300,
      expiryType: json['expiryType'] ?? 'monthly',
      expiryDays: json['expiryDays'] ?? 30,
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (json['endDate'] as Timestamp?)?.toDate(),
      cancelledAt: (json['cancelledAt'] as Timestamp?)?.toDate(),
      activatedAt: (json['activatedAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingPlanId: json['pendingPlanId'],
      pendingPlanName: json['pendingPlanName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'planName': planName,
      'status': status,
      'messagesUsed': messagesUsed,
      'contactsUsed': contactsUsed,
      'campaignsUsed': campaignsUsed,
      'botsUsed': botsUsed,
      'templatesUsed': templatesUsed,
      'aiMessagesUsed': aiMessagesUsed,
      'maxMessages': maxMessages,
      'maxContacts': maxContacts,
      'maxCampaigns': maxCampaigns,
      'maxBots': maxBots,
      'maxTemplates': maxTemplates,
      'maxAiMessages': maxAiMessages,
      'expiryType': expiryType,
      'expiryDays': expiryDays,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'activatedAt': activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Is active — true if status=active AND (lifetime OR no end date OR end date in future)
  /// NOTE: endDate == null on a non-lifetime plan means "no expiry set" = treat as active
  bool get isActive =>
      status == 'active' &&
      (isLifetime || endDate == null || DateTime.now().isBefore(endDate!));

  /// Is pending admin activation
  bool get isPending => status == 'pending';

  /// Has a pending upgrade request (user requested but admin hasn't approved yet)
  bool get hasPendingUpgrade => pendingPlanId != null && pendingPlanId!.isNotEmpty;

  /// Is expired — only when status=active but end date has passed
  bool get isExpired =>
      status == 'active' && !isLifetime && endDate != null && DateTime.now().isAfter(endDate!);

  /// Is lifetime plan
  bool get isLifetime => expiryType == 'lifetime';

  /// Days remaining
  int get daysRemaining {
    if (isLifetime) return -1; // infinite
    if (endDate == null) return -1; // no expiry set = treat as unlimited
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Days remaining label
  String get daysRemainingLabel {
    if (isLifetime || endDate == null) return 'Lifetime';
    final d = daysRemaining;
    return d == 0 ? 'Expired' : '$d days remaining';
  }

  /// Usage percentages (0 = unlimited → 0%)
  double get messageUsagePercent {
    if (maxMessages == 0) return 0;
    return (messagesUsed / maxMessages * 100).clamp(0, 100);
  }

  double get contactUsagePercent {
    if (maxContacts == 0) return 0;
    return (contactsUsed / maxContacts * 100).clamp(0, 100);
  }

  double get templateUsagePercent {
    if (maxTemplates == 0) return 0;
    return (templatesUsed / maxTemplates * 100).clamp(0, 100);
  }

  /// Remaining counts (-1 = unlimited)
  int get messagesRemaining => maxMessages == 0 ? -1 : maxMessages - messagesUsed;
  int get contactsRemaining => maxContacts == 0 ? -1 : maxContacts - contactsUsed;
  int get botsRemaining => maxBots == 0 ? -1 : maxBots - botsUsed;
  int get templatesRemaining => maxTemplates == 0 ? -1 : maxTemplates - templatesUsed;
  int get aiMessagesRemaining => maxAiMessages == 0 ? -1 : maxAiMessages - aiMessagesUsed;

  /// Can perform action checks (0 = unlimited)
  bool get canSendMessage => maxMessages == 0 || messagesUsed < maxMessages;
  bool get canAddContact => maxContacts == 0 || contactsUsed < maxContacts;
  bool get canCreateCampaign => maxCampaigns == 0 || campaignsUsed < maxCampaigns;
  bool get canCreateBot => maxBots == 0 || botsUsed < maxBots;
  bool get canCreateTemplate => maxTemplates == 0 || templatesUsed < maxTemplates;
  bool get canUseAiBot => maxAiMessages == 0 || aiMessagesUsed < maxAiMessages;

  /// Limit label
  String limitLabel(int value) => value == 0 ? 'Unlimited' : '$value';
}
