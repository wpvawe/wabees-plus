import 'package:cloud_firestore/cloud_firestore.dart';

/// 📇 CONTACT MODEL
class ContactModel {
  final String id;
  final String phone;          // WhatsApp phone: +923001234567
  final String name;
  final String? email;
  final String? company;
  final String? notes;
  final List<String> tags;
  final String? group;          // Contact group: VIP, Leads, Customers, etc.
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int totalMessages;

  const ContactModel({
    required this.id,
    required this.phone,
    required this.name,
    this.email,
    this.company,
    this.notes,
    this.tags = const [],
    this.group,
    this.profileImageUrl,
    required this.createdAt,
    this.lastMessageAt,
    this.totalMessages = 0,
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

  factory ContactModel.fromJson(Map<String, dynamic> json, String docId) {
    return ContactModel(
      id: docId,
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      company: json['company'],
      notes: json['notes'],
      tags: List<String>.from(json['tags'] ?? []),
      group: json['group'],
      profileImageUrl: json['profileImageUrl'],
      createdAt: _parseDate(json['createdAt']),
      lastMessageAt: _parseDateNullable(json['lastMessageAt']),
      totalMessages: json['totalMessages'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      'email': email,
      'company': company,
      'notes': notes,
      'tags': tags,
      'group': group,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'totalMessages': totalMessages,
    };
  }

  ContactModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? company,
    String? notes,
    List<String>? tags,
    String? group,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? totalMessages,
  }) {
    return ContactModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      group: group ?? this.group,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      totalMessages: totalMessages ?? this.totalMessages,
    );
  }

  /// Display name: name or phone
  String get displayName => name.isNotEmpty ? name : phone;

  /// Group label for display
  String get groupLabel => group ?? 'Uncategorized';
}
