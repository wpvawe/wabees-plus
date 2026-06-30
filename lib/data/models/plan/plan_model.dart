import 'package:cloud_firestore/cloud_firestore.dart';

/// 💎 PLAN MODEL — Subscription plan definition (Admin creates these)
/// Convention: 0 = unlimited for all limit fields
class PlanModel {
  final String id;
  final String name;
  final String description;
  final double priceMonthly;
  final double? priceYearly;
  final String currency;

  // Limits (0 = unlimited)
  final int maxMessages;
  final int maxContacts;
  final int maxCampaigns;
  final int maxBots;
  final int maxTemplates;
  final int maxAiMessages; // AI bot monthly message limit (0 = unlimited)

  // Features
  final bool hasAnalytics;
  final bool hasPrioritySupport;
  final bool hasApiAccess;
  final List<String> features;

  // Expiry
  final String expiryType; // 'monthly', 'yearly', 'lifetime'
  final int expiryDays;    // 30, 365, or 0 for lifetime

  // Meta
  final bool isActive;
  final int sortOrder;
  final bool isPopular;
  final bool isWelcomePlan; // System plan, auto-assigned to new users
  final DateTime createdAt;

  const PlanModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.priceMonthly,
    this.priceYearly,
    this.currency = 'PKR',
    this.maxMessages = 1000,
    this.maxContacts = 100,
    this.maxCampaigns = 5,
    this.maxBots = 2,
    this.maxTemplates = 10,
    this.maxAiMessages = 300,
    this.hasAnalytics = false,
    this.hasPrioritySupport = false,
    this.hasApiAccess = false,
    this.features = const [],
    this.expiryType = 'monthly',
    this.expiryDays = 30,
    this.isActive = true,
    this.sortOrder = 0,
    this.isPopular = false,
    this.isWelcomePlan = false,
    required this.createdAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json, String docId) {
    return PlanModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      priceMonthly: (json['priceMonthly'] ?? 0).toDouble(),
      priceYearly: json['priceYearly']?.toDouble(),
      currency: json['currency'] ?? 'PKR',
      maxMessages: json['maxMessages'] ?? 1000,
      maxContacts: json['maxContacts'] ?? 100,
      maxCampaigns: json['maxCampaigns'] ?? 5,
      maxBots: json['maxBots'] ?? 2,
      maxTemplates: json['maxTemplates'] ?? 10,
      maxAiMessages: json['maxAiMessages'] ?? 300,
      hasAnalytics: json['hasAnalytics'] ?? false,
      hasPrioritySupport: json['hasPrioritySupport'] ?? false,
      hasApiAccess: json['hasApiAccess'] ?? false,
      features: List<String>.from(json['features'] ?? []),
      expiryType: json['expiryType'] ?? 'monthly',
      expiryDays: json['expiryDays'] ?? 30,
      isActive: json['isActive'] ?? true,
      sortOrder: json['sortOrder'] ?? 0,
      isPopular: json['isPopular'] ?? false,
      isWelcomePlan: json['isWelcomePlan'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'priceMonthly': priceMonthly,
      'priceYearly': priceYearly,
      'currency': currency,
      'maxMessages': maxMessages,
      'maxContacts': maxContacts,
      'maxCampaigns': maxCampaigns,
      'maxBots': maxBots,
      'maxTemplates': maxTemplates,
      'maxAiMessages': maxAiMessages,
      'hasAnalytics': hasAnalytics,
      'hasPrioritySupport': hasPrioritySupport,
      'hasApiAccess': hasApiAccess,
      'features': features,
      'expiryType': expiryType,
      'expiryDays': expiryDays,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'isPopular': isPopular,
      'isWelcomePlan': isWelcomePlan,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  PlanModel copyWith({
    String? id,
    String? name,
    String? description,
    double? priceMonthly,
    double? priceYearly,
    String? currency,
    int? maxMessages,
    int? maxContacts,
    int? maxCampaigns,
    int? maxBots,
    int? maxTemplates,
    int? maxAiMessages,
    bool? hasAnalytics,
    bool? hasPrioritySupport,
    bool? hasApiAccess,
    List<String>? features,
    String? expiryType,
    int? expiryDays,
    bool? isActive,
    int? sortOrder,
    bool? isPopular,
    bool? isWelcomePlan,
    DateTime? createdAt,
  }) {
    return PlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      priceYearly: priceYearly ?? this.priceYearly,
      currency: currency ?? this.currency,
      maxMessages: maxMessages ?? this.maxMessages,
      maxContacts: maxContacts ?? this.maxContacts,
      maxCampaigns: maxCampaigns ?? this.maxCampaigns,
      maxBots: maxBots ?? this.maxBots,
      maxTemplates: maxTemplates ?? this.maxTemplates,
      maxAiMessages: maxAiMessages ?? this.maxAiMessages,
      hasAnalytics: hasAnalytics ?? this.hasAnalytics,
      hasPrioritySupport: hasPrioritySupport ?? this.hasPrioritySupport,
      hasApiAccess: hasApiAccess ?? this.hasApiAccess,
      features: features ?? this.features,
      expiryType: expiryType ?? this.expiryType,
      expiryDays: expiryDays ?? this.expiryDays,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      isPopular: isPopular ?? this.isPopular,
      isWelcomePlan: isWelcomePlan ?? this.isWelcomePlan,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Formatted price
  String get formattedPrice {
    if (priceMonthly == 0) return 'Free';
    final suffix = expiryType == 'yearly' ? '/yr' : expiryType == 'lifetime' ? '' : '/mo';
    return '$currency ${priceMonthly.toStringAsFixed(0)}$suffix';
  }

  /// Is unlimited for a given value (0 = unlimited)
  bool isUnlimited(int value) => value == 0;

  /// Is unlimited messages
  bool get isUnlimitedMessages => maxMessages == 0;

  /// Limit label (0 = Unlimited)
  String limitLabel(int value) => value == 0 ? 'Unlimited' : '$value';

  /// Expiry label
  String get expiryLabel {
    switch (expiryType) {
      case 'lifetime':
        return 'Lifetime';
      case 'yearly':
        return '1 Year';
      case 'monthly':
      default:
        return '30 Days';
    }
  }

  /// Is lifetime plan
  bool get isLifetime => expiryType == 'lifetime';

  /// Welcome plan factory
  static PlanModel welcomePlan() {
    return PlanModel(
      id: 'welcome_plan',
      name: 'Welcome',
      description: 'Free starter plan for new users',
      priceMonthly: 0,
      currency: 'PKR',
      maxMessages: 250,
      maxContacts: 1000,
      maxCampaigns: 2,
      maxBots: 10,
      maxTemplates: 5,
      maxAiMessages: 100,
      expiryType: 'lifetime',
      expiryDays: 0,
      isActive: true,
      sortOrder: -1,
      isPopular: false,
      isWelcomePlan: true,
      createdAt: DateTime.now(),
    );
  }
}
