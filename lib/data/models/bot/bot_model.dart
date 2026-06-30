import 'package:cloud_firestore/cloud_firestore.dart';
import 'bot_trigger_type.dart';

/// 🤖 BOT MODEL — Auto-reply bot configuration with WhatsApp interactive buttons
class BotModel {
  final String id;
  final String name;
  final String description;
  final bool isActive;

  // Trigger config
  final BotTriggerType triggerType;
  final List<String> triggerKeywords;
  final bool caseSensitive;

  // Response config
  final String responseText;
  final String? headerText; // Header text (shown above message body)
  final String? templateName;
  final int delaySeconds;

  // WhatsApp Interactive Buttons (Quick Reply — max 3)
  final List<BotQuickReply> quickReplies;

  // WhatsApp CTA Button (Call-to-Action — URL or Phone)
  final BotCtaButton? ctaButton;

  // Footer text (shown below message, above buttons)
  final String? footerText;

  // Limits
  final int? maxTriggersPerContact;
  final int? cooldownMinutes;

  // Multi-response: additional messages sent after the main response
  final List<BotAdditionalResponse> additionalResponses;

  // Metadata
  final int totalTriggered;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const BotModel({
    required this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
    required this.triggerType,
    this.triggerKeywords = const [],
    this.caseSensitive = false,
    required this.responseText,
    this.headerText,
    this.templateName,
    this.delaySeconds = 0,
    this.quickReplies = const [],
    this.ctaButton,
    this.footerText,
    this.maxTriggersPerContact,
    this.cooldownMinutes,
    this.additionalResponses = const [],
    this.totalTriggered = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Whether this bot uses interactive buttons
  bool get hasButtons => quickReplies.isNotEmpty || ctaButton != null;

  /// Parse date that may be Firestore Timestamp or ISO string
  static DateTime _parseDate(dynamic value, [DateTime? fallback]) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
    return fallback ?? DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory BotModel.fromJson(Map<String, dynamic> json, String docId) {
    return BotModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? true,
      triggerType: BotTriggerType.fromString(json['triggerType'] ?? 'keyword'),
      triggerKeywords: List<String>.from(json['triggerKeywords'] ?? []),
      caseSensitive: json['caseSensitive'] ?? false,
      responseText: json['responseText'] ?? '',
      headerText: json['headerText'],
      templateName: json['templateName'],
      delaySeconds: json['delaySeconds'] ?? 0,
      quickReplies: (json['quickReplies'] as List<dynamic>?)
              ?.map((e) => BotQuickReply.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      ctaButton: json['ctaButton'] != null
          ? BotCtaButton.fromJson(Map<String, dynamic>.from(json['ctaButton']))
          : null,
      footerText: json['footerText'],
      maxTriggersPerContact: json['maxTriggersPerContact'],
      cooldownMinutes: json['cooldownMinutes'],
      additionalResponses: (json['additionalResponses'] as List<dynamic>?)
              ?.map((e) => BotAdditionalResponse.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      totalTriggered: json['totalTriggered'] ?? 0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDateNullable(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'isActive': isActive,
      'triggerType': triggerType.name,
      'triggerKeywords': triggerKeywords,
      'caseSensitive': caseSensitive,
      'responseText': responseText,
      'headerText': headerText,
      'templateName': templateName,
      'delaySeconds': delaySeconds,
      'quickReplies': quickReplies.map((e) => e.toJson()).toList(),
      'ctaButton': ctaButton?.toJson(),
      'footerText': footerText,
      'maxTriggersPerContact': maxTriggersPerContact,
      'cooldownMinutes': cooldownMinutes,
      'additionalResponses': additionalResponses.map((e) => e.toJson()).toList(),
      'totalTriggered': totalTriggered,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  BotModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    BotTriggerType? triggerType,
    List<String>? triggerKeywords,
    bool? caseSensitive,
    String? responseText,
    String? headerText,
    String? templateName,
    int? delaySeconds,
    List<BotQuickReply>? quickReplies,
    BotCtaButton? ctaButton,
    String? footerText,
    int? maxTriggersPerContact,
    int? cooldownMinutes,
    List<BotAdditionalResponse>? additionalResponses,
    int? totalTriggered,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BotModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      triggerType: triggerType ?? this.triggerType,
      triggerKeywords: triggerKeywords ?? this.triggerKeywords,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      responseText: responseText ?? this.responseText,
      headerText: headerText ?? this.headerText,
      templateName: templateName ?? this.templateName,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      quickReplies: quickReplies ?? this.quickReplies,
      ctaButton: ctaButton ?? this.ctaButton,
      footerText: footerText ?? this.footerText,
      maxTriggersPerContact: maxTriggersPerContact ?? this.maxTriggersPerContact,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      additionalResponses: additionalResponses ?? this.additionalResponses,
      totalTriggered: totalTriggered ?? this.totalTriggered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this bot should trigger for the given message
  bool shouldTrigger(String incomingMessage) {
    if (!isActive) return false;

    final msg = caseSensitive ? incomingMessage : incomingMessage.toLowerCase();

    switch (triggerType) {
      case BotTriggerType.allMessages:
        return true;
      case BotTriggerType.exactMatch:
        return triggerKeywords.any((kw) =>
            msg == (caseSensitive ? kw : kw.toLowerCase()));
      case BotTriggerType.contains:
        return triggerKeywords.any((kw) =>
            msg.contains(caseSensitive ? kw : kw.toLowerCase()));
      case BotTriggerType.startsWith:
        return triggerKeywords.any((kw) =>
            msg.startsWith(caseSensitive ? kw : kw.toLowerCase()));
      case BotTriggerType.keyword:
        final words = msg.split(RegExp(r'\s+'));
        return triggerKeywords.any((kw) =>
            words.contains(caseSensitive ? kw : kw.toLowerCase()));
      case BotTriggerType.regex:
        return triggerKeywords.any((pattern) {
          try {
            return RegExp(pattern, caseSensitive: caseSensitive).hasMatch(incomingMessage);
          } catch (_) {
            return false;
          }
        });
      case BotTriggerType.welcomeMessage:
        return true; // Always triggers, acts as default reply
    }
  }

  String get statusLabel => isActive ? 'Active' : 'Inactive';

  String get triggerSummary {
    if (triggerType == BotTriggerType.allMessages) return 'All messages';
    if (triggerKeywords.isEmpty) return 'No triggers set';
    if (triggerKeywords.length == 1) return triggerKeywords.first;
    return '${triggerKeywords.length} triggers';
  }

  String get buttonsSummary {
    final parts = <String>[];
    if (quickReplies.isNotEmpty) parts.add('${quickReplies.length} Quick Reply');
    if (ctaButton != null) parts.add('1 CTA');
    return parts.isEmpty ? 'No buttons' : parts.join(' + ');
  }
}

/// WhatsApp Quick Reply Button (max 3 per message)
class BotQuickReply {
  final String id;
  final String title; // Max 20 chars

  const BotQuickReply({required this.id, required this.title});

  factory BotQuickReply.fromJson(Map<String, dynamic> json) {
    return BotQuickReply(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

/// WhatsApp Call-to-Action Button (URL or Phone)
class BotCtaButton {
  final CtaButtonType type;
  final String title; // Max 20 chars
  final String value; // URL or phone number

  const BotCtaButton({
    required this.type,
    required this.title,
    required this.value,
  });

  factory BotCtaButton.fromJson(Map<String, dynamic> json) {
    return BotCtaButton(
      type: CtaButtonType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CtaButtonType.url,
      ),
      title: json['title'] ?? '',
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'value': value,
      };
}

enum CtaButtonType {
  url,
  phone;

  String get label {
    switch (this) {
      case CtaButtonType.url:
        return 'Visit Website';
      case CtaButtonType.phone:
        return 'Call Phone';
    }
  }

  IconLabel get iconLabel {
    switch (this) {
      case CtaButtonType.url:
        return const IconLabel('🌐', 'URL');
      case CtaButtonType.phone:
        return const IconLabel('📞', 'Phone');
    }
  }
}

/// Additional response message for multi-message bots
class BotAdditionalResponse {
  final String responseText;
  final int delaySeconds; // Delay before sending this response
  final String? headerText;
  final String? footerText;
  final List<BotQuickReply> quickReplies;
  final BotCtaButton? ctaButton;

  const BotAdditionalResponse({
    required this.responseText,
    this.delaySeconds = 1,
    this.headerText,
    this.footerText,
    this.quickReplies = const [],
    this.ctaButton,
  });

  factory BotAdditionalResponse.fromJson(Map<String, dynamic> json) {
    return BotAdditionalResponse(
      responseText: json['responseText'] ?? '',
      delaySeconds: json['delaySeconds'] ?? 1,
      headerText: json['headerText'],
      footerText: json['footerText'],
      quickReplies: (json['quickReplies'] as List<dynamic>?)
              ?.map((e) => BotQuickReply.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      ctaButton: json['ctaButton'] != null
          ? BotCtaButton.fromJson(Map<String, dynamic>.from(json['ctaButton']))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'responseText': responseText,
        'delaySeconds': delaySeconds,
        'headerText': headerText,
        'footerText': footerText,
        'quickReplies': quickReplies.map((e) => e.toJson()).toList(),
        'ctaButton': ctaButton?.toJson(),
      };
}

class IconLabel {
  final String icon;
  final String label;
  const IconLabel(this.icon, this.label);
}
