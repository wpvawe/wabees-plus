import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';
import 'user_status.dart';

/// 🎯 USER MODEL - COMPLETE
class UserModel {
  final String id;
  final String email;
  final String businessName;
  final String phoneNumber;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profileImageUrl;
  final String? whatsappPhoneNumberId;
  final String? whatsappAccessToken;
  final bool whatsappConnected;
  final int totalMessages;
  final int totalContacts;
  final int totalBots;
  final int totalCampaigns;
  final String? fcmToken;
  final String? dataOwner; // If set, this user is an agent sharing owner's data
  final bool aiBotEnabled; // Admin controls if user can use AI bot feature
  final bool isOnline;     // Real-time presence status

  /// Alias for phoneNumber (used in search)
  String get phone => phoneNumber;

  const UserModel({
    required this.id,
    required this.email,
    required this.businessName,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.profileImageUrl,
    this.whatsappPhoneNumberId,
    this.whatsappAccessToken,
    this.whatsappConnected = false,
    this.totalMessages = 0,
    this.totalContacts = 0,
    this.totalBots = 0,
    this.totalCampaigns = 0,
    this.fcmToken,
    this.dataOwner,
    this.aiBotEnabled = false,
    this.isOnline = false,
  });

  // ============ FROM FIRESTORE ============
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      businessName: data['businessName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.user,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => UserStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      profileImageUrl: data['profileImageUrl'],
      whatsappPhoneNumberId: data['whatsappPhoneNumberId'],
      whatsappAccessToken: data['whatsappAccessToken'],
      whatsappConnected: data['whatsappConnected'] ?? false,
      totalMessages: data['totalMessages'] ?? 0,
      totalContacts: data['totalContacts'] ?? 0,
      totalBots: data['totalBots'] ?? 0,
      totalCampaigns: data['totalCampaigns'] ?? 0,
      fcmToken: data['fcmToken'],
      dataOwner: data['dataOwner'],
      aiBotEnabled: data['aiBotEnabled'] ?? false,
      isOnline: data['isOnline'] ?? false,
    );
  }

  // ============ TO JSON ============
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'profileImageUrl': profileImageUrl,
      'whatsappPhoneNumberId': whatsappPhoneNumberId,
      'whatsappAccessToken': whatsappAccessToken,
      'whatsappConnected': whatsappConnected,
      'totalMessages': totalMessages,
      'totalContacts': totalContacts,
      'totalBots': totalBots,
      'totalCampaigns': totalCampaigns,
      'fcmToken': fcmToken,
      if (dataOwner != null) 'dataOwner': dataOwner,
      'aiBotEnabled': aiBotEnabled,
    };
  }

  // ============ COPY WITH ============
  UserModel copyWith({
    String? id,
    String? email,
    String? businessName,
    String? phoneNumber,
    UserRole? role,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    String? whatsappPhoneNumberId,
    String? whatsappAccessToken,
    bool? whatsappConnected,
    int? totalMessages,
    int? totalContacts,
    int? totalBots,
    int? totalCampaigns,
    String? fcmToken,
    String? dataOwner,
    bool? aiBotEnabled,
    bool? isOnline,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      whatsappPhoneNumberId: whatsappPhoneNumberId ?? this.whatsappPhoneNumberId,
      whatsappAccessToken: whatsappAccessToken ?? this.whatsappAccessToken,
      whatsappConnected: whatsappConnected ?? this.whatsappConnected,
      totalMessages: totalMessages ?? this.totalMessages,
      totalContacts: totalContacts ?? this.totalContacts,
      totalBots: totalBots ?? this.totalBots,
      totalCampaigns: totalCampaigns ?? this.totalCampaigns,
      fcmToken: fcmToken ?? this.fcmToken,
      dataOwner: dataOwner ?? this.dataOwner,
      aiBotEnabled: aiBotEnabled ?? this.aiBotEnabled,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
