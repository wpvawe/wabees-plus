import 'package:cloud_firestore/cloud_firestore.dart';

/// 📋 TEMPLATE MODEL (WhatsApp message templates)
class TemplateModel {
  final String id;
  final String? metaTemplateId; // Meta API template ID for editing
  final String name;
  final String category;        // MARKETING, UTILITY, AUTHENTICATION
  final String languageCode;    // en_US, ur, etc.
  final String body;            // Template body with {{name}} variables
  final String? header;         // Optional header text
  final String? footer;         // Optional footer text
  final List<Map<String, dynamic>> buttons; // Template buttons (CTA, Quick Reply)
  final List<String> variables; // Variable names for placeholders
  final Map<String, String> variableSamples; // Variable sample values
  final Map<String, String> variableTypes;   // Variable types: 'string' | 'number'
  final String status;          // APPROVED, PENDING, REJECTED, PAUSED
  final bool isSynced;          // Synced from Meta or created locally
  final String? qualityScore;   // GREEN, YELLOW, RED
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TemplateModel({
    required this.id,
    this.metaTemplateId,
    required this.name,
    required this.category,
    required this.languageCode,
    required this.body,
    this.header,
    this.footer,
    this.buttons = const [],
    this.variables = const [],
    this.variableSamples = const {},
    this.variableTypes = const {},
    this.status = 'PENDING',
    this.isSynced = false,
    this.qualityScore,
    required this.createdAt,
    this.updatedAt,
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

  /// Extract variables from body text {{name}}, {{1}}, {{order_number}}, etc.
  static List<String> extractVariables(String body) {
    // Match both named vars {{name}} and numbered vars {{1}}, {{2}} from Meta API
    final regex = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');
    final matches = regex.allMatches(body);
    final seen = <String>{};
    final result = <String>[];
    for (final m in matches) {
      final name = m.group(1)!;
      if (seen.add(name)) result.add(name);
    }
    return result;
  }

  factory TemplateModel.fromJson(Map<String, dynamic> json, String docId) {
    return TemplateModel(
      id: docId,
      metaTemplateId: json['metaTemplateId'],
      name: json['name'] ?? '',
      category: (json['category'] ?? 'utility').toString().toUpperCase(),
      languageCode: json['languageCode'] ?? 'en_US',
      body: json['body'] ?? '',
      header: json['header'],
      footer: json['footer'],
      buttons: (json['buttons'] as List?)?.map((b) => Map<String, dynamic>.from(b as Map)).toList() ?? const [],
      variables: List<String>.from(json['variables'] ?? []),
      variableSamples: Map<String, String>.from(json['variableSamples'] ?? {}),
      variableTypes: Map<String, String>.from(json['variableTypes'] ?? {}),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      isSynced: json['isSynced'] ?? false,
      qualityScore: json['qualityScore'],
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDateNullable(json['updatedAt']),
    );
  }

  /// Parse from Meta API response
  factory TemplateModel.fromMetaApi(Map<String, dynamic> json) {
    String bodyText = '';
    String? headerText;
    String? footerText;
    List<Map<String, dynamic>> buttons = [];

    final components = json['components'] as List? ?? [];
    for (final comp in components) {
      switch (comp['type']) {
        case 'BODY':
          bodyText = comp['text'] ?? '';
          break;
        case 'HEADER':
          if (comp['format'] == 'TEXT') {
            headerText = comp['text'];
          }
          break;
        case 'FOOTER':
          footerText = comp['text'];
          break;
        case 'BUTTONS':
          final btns = comp['buttons'] as List? ?? [];
          buttons = btns.map((b) => Map<String, dynamic>.from(b as Map)).toList();
          break;
      }
    }

    // Extract variables from body {{1}}, {{2}}, etc.
    final vars = TemplateModel.extractVariables(bodyText);

    // Get quality score if available
    final qualityScore = json['quality_score']?['score'];

    return TemplateModel(
      id: json['id']?.toString() ?? '',
      metaTemplateId: json['id']?.toString(),
      name: json['name'] ?? '',
      category: (json['category'] ?? 'UTILITY').toString().toUpperCase(),
      languageCode: (json['language'] is Map)
          ? json['language']['code'] ?? 'en_US'
          : json['language'] ?? 'en_US',
      body: bodyText,
      header: headerText,
      footer: footerText,
      buttons: buttons,
      variables: vars,
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      isSynced: true,
      qualityScore: qualityScore?.toString(),
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metaTemplateId': metaTemplateId,
      'name': name,
      'category': category.toUpperCase(),
      'languageCode': languageCode,
      'body': body,
      'header': header,
      'footer': footer,
      'buttons': buttons,
      'variables': variables,
      'variableSamples': variableSamples,
      'variableTypes': variableTypes,
      'status': status.toUpperCase(),
      'isSynced': isSynced,
      'qualityScore': qualityScore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  TemplateModel copyWith({
    String? id,
    String? metaTemplateId,
    String? name,
    String? category,
    String? languageCode,
    String? body,
    String? header,
    String? footer,
    List<Map<String, dynamic>>? buttons,
    List<String>? variables,
    Map<String, String>? variableSamples,
    Map<String, String>? variableTypes,
    String? status,
    bool? isSynced,
    String? qualityScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      metaTemplateId: metaTemplateId ?? this.metaTemplateId,
      name: name ?? this.name,
      category: category ?? this.category,
      languageCode: languageCode ?? this.languageCode,
      body: body ?? this.body,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      buttons: buttons ?? this.buttons,
      variables: variables ?? this.variables,
      variableSamples: variableSamples ?? this.variableSamples,
      variableTypes: variableTypes ?? this.variableTypes,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
      qualityScore: qualityScore ?? this.qualityScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether the template has variables to fill
  bool get hasVariables => variables.isNotEmpty;

  /// Preview text (body with truncation)
  String get preview {
    if (body.length > 80) return '${body.substring(0, 80)}...';
    return body;
  }

  /// Category label
  String get categoryLabel {
    switch (category.toUpperCase()) {
      case 'MARKETING':
        return 'Marketing';
      case 'UTILITY':
        return 'Utility';
      case 'AUTHENTICATION':
        return 'Authentication';
      default:
        return category;
    }
  }

  /// Status helpers
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isPaused => status.toUpperCase() == 'PAUSED';

  /// Whether this template can be edited on Meta
  bool get canEdit => metaTemplateId != null && metaTemplateId!.isNotEmpty;

  /// Whether this template can be used to send messages
  bool get canSend => isApproved;

  /// Status display label
  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Approved';
      case 'PENDING':
        return 'Pending Review';
      case 'REJECTED':
        return 'Rejected';
      case 'PAUSED':
        return 'Paused';
      default:
        return status;
    }
  }
}
