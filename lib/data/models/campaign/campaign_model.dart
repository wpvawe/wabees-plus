import 'package:cloud_firestore/cloud_firestore.dart';
import 'campaign_status.dart';

/// 📊 CAMPAIGN MODEL — Bulk messaging campaigns
class CampaignModel {
  final String id;
  final String name;
  final String description;
  final CampaignStatus status;

  // Message config
  final String messageType;       // 'text' or 'template'
  final String messageBody;       // Text content or template name
  final String? templateName;
  final String? templateLanguage;
  final String? selectedTemplateId; // Firestore template doc ID

  // Template variables
  final List<String> templateVariables;             // e.g. ['name', 'amount']
  final String variableSource;                      // 'static' or 'csv'
  final Map<String, String> staticVariableValues;   // Same value for all recipients
  final List<Map<String, String>> recipientData;    // Per-recipient: [{phone, name, amount}, ...]

  // Audience
  final List<String> audiencePhones;   // Target phone numbers
  final List<String> audienceTags;     // Or target by contact tags
  final List<String> audienceGroups;   // Or target by contact groups
  final int totalRecipients;

  // Analytics
  final int sentCount;
  final int deliveredCount;
  final int readCount;
  final int failedCount;

  // Schedule
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const CampaignModel({
    required this.id,
    required this.name,
    this.description = '',
    this.status = CampaignStatus.draft,
    this.messageType = 'text',
    required this.messageBody,
    this.templateName,
    this.templateLanguage,
    this.selectedTemplateId,
    this.templateVariables = const [],
    this.variableSource = 'static',
    this.staticVariableValues = const {},
    this.recipientData = const [],
    this.audiencePhones = const [],
    this.audienceTags = const [],
    this.audienceGroups = const [],
    this.totalRecipients = 0,
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.readCount = 0,
    this.failedCount = 0,
    this.scheduledAt,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

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

  factory CampaignModel.fromJson(Map<String, dynamic> json, String docId) {
    return CampaignModel(
      id: docId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      status: CampaignStatus.fromString(json['status'] ?? 'draft'),
      messageType: json['messageType'] ?? 'text',
      messageBody: json['messageBody'] ?? '',
      templateName: json['templateName'],
      templateLanguage: json['templateLanguage'],
      selectedTemplateId: json['selectedTemplateId'],
      templateVariables: List<String>.from(json['templateVariables'] ?? []),
      variableSource: json['variableSource'] ?? 'static',
      staticVariableValues: Map<String, String>.from(json['staticVariableValues'] ?? {}),
      recipientData: (json['recipientData'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList() ?? [],
      audiencePhones: List<String>.from(json['audiencePhones'] ?? []),
      audienceTags: List<String>.from(json['audienceTags'] ?? []),
      audienceGroups: List<String>.from(json['audienceGroups'] ?? []),
      totalRecipients: json['totalRecipients'] ?? 0,
      sentCount: json['sentCount'] ?? 0,
      deliveredCount: json['deliveredCount'] ?? 0,
      readCount: json['readCount'] ?? 0,
      failedCount: json['failedCount'] ?? 0,
      scheduledAt: _parseDateNullable(json['scheduledAt']),
      createdAt: _parseDate(json['createdAt']),
      startedAt: _parseDateNullable(json['startedAt']),
      completedAt: _parseDateNullable(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'status': status.name,
      'messageType': messageType,
      'messageBody': messageBody,
      'templateName': templateName,
      'templateLanguage': templateLanguage,
      'selectedTemplateId': selectedTemplateId,
      'templateVariables': templateVariables,
      'variableSource': variableSource,
      'staticVariableValues': staticVariableValues,
      'recipientData': recipientData,
      'audiencePhones': audiencePhones,
      'audienceTags': audienceTags,
      'audienceGroups': audienceGroups,
      'totalRecipients': totalRecipients,
      'sentCount': sentCount,
      'deliveredCount': deliveredCount,
      'readCount': readCount,
      'failedCount': failedCount,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  CampaignModel copyWith({
    String? id,
    String? name,
    String? description,
    CampaignStatus? status,
    String? messageType,
    String? messageBody,
    String? templateName,
    String? templateLanguage,
    String? selectedTemplateId,
    List<String>? templateVariables,
    String? variableSource,
    Map<String, String>? staticVariableValues,
    List<Map<String, String>>? recipientData,
    List<String>? audiencePhones,
    List<String>? audienceTags,
    List<String>? audienceGroups,
    int? totalRecipients,
    int? sentCount,
    int? deliveredCount,
    int? readCount,
    int? failedCount,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      messageType: messageType ?? this.messageType,
      messageBody: messageBody ?? this.messageBody,
      templateName: templateName ?? this.templateName,
      templateLanguage: templateLanguage ?? this.templateLanguage,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      templateVariables: templateVariables ?? this.templateVariables,
      variableSource: variableSource ?? this.variableSource,
      staticVariableValues: staticVariableValues ?? this.staticVariableValues,
      recipientData: recipientData ?? this.recipientData,
      audiencePhones: audiencePhones ?? this.audiencePhones,
      audienceTags: audienceTags ?? this.audienceTags,
      audienceGroups: audienceGroups ?? this.audienceGroups,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      sentCount: sentCount ?? this.sentCount,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      readCount: readCount ?? this.readCount,
      failedCount: failedCount ?? this.failedCount,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Delivery rate percentage
  double get deliveryRate {
    if (sentCount == 0) return 0;
    return (deliveredCount / sentCount) * 100;
  }

  /// Read rate percentage
  double get readRate {
    if (deliveredCount == 0) return 0;
    return (readCount / deliveredCount) * 100;
  }

  /// Progress percentage
  double get progress {
    if (totalRecipients == 0) return 0;
    return ((sentCount + failedCount) / totalRecipients) * 100;
  }

  /// Is using template
  bool get isTemplate => messageType == 'template';
}
