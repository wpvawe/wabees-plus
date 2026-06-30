import 'package:cloud_firestore/cloud_firestore.dart';

/// 📱 WHATSAPP CONFIG MODEL
class WhatsappConfig {
  final String phoneNumberId;
  final String accessToken;
  final String businessAccountId;
  final String webhookVerifyToken;
  final bool isConnected;
  final DateTime? connectedAt;
  final DateTime? lastVerifiedAt;
  final String? displayPhoneNumber;
  final String? qualityRating;

  const WhatsappConfig({
    required this.phoneNumberId,
    required this.accessToken,
    this.businessAccountId = '',
    this.webhookVerifyToken = '',
    this.isConnected = false,
    this.connectedAt,
    this.lastVerifiedAt,
    this.displayPhoneNumber,
    this.qualityRating,
  });

  factory WhatsappConfig.empty() => const WhatsappConfig(
    phoneNumberId: '',
    accessToken: '',
  );

  factory WhatsappConfig.fromJson(Map<String, dynamic> json) {
    return WhatsappConfig(
      phoneNumberId: json['phoneNumberId'] ?? '',
      accessToken: json['accessToken'] ?? '',
      businessAccountId: json['businessAccountId'] ?? '',
      webhookVerifyToken: json['webhookVerifyToken'] ?? '',
      isConnected: json['isConnected'] ?? false,
      connectedAt: (json['connectedAt'] as Timestamp?)?.toDate(),
      lastVerifiedAt: (json['lastVerifiedAt'] as Timestamp?)?.toDate(),
      displayPhoneNumber: json['displayPhoneNumber'],
      qualityRating: json['qualityRating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneNumberId': phoneNumberId,
      'accessToken': accessToken,
      'businessAccountId': businessAccountId,
      'webhookVerifyToken': webhookVerifyToken,
      'isConnected': isConnected,
      'connectedAt': connectedAt != null ? Timestamp.fromDate(connectedAt!) : null,
      'lastVerifiedAt': lastVerifiedAt != null ? Timestamp.fromDate(lastVerifiedAt!) : null,
      'displayPhoneNumber': displayPhoneNumber,
      'qualityRating': qualityRating,
    };
  }

  WhatsappConfig copyWith({
    String? phoneNumberId,
    String? accessToken,
    String? businessAccountId,
    String? webhookVerifyToken,
    bool? isConnected,
    DateTime? connectedAt,
    DateTime? lastVerifiedAt,
    String? displayPhoneNumber,
    String? qualityRating,
  }) {
    return WhatsappConfig(
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      accessToken: accessToken ?? this.accessToken,
      businessAccountId: businessAccountId ?? this.businessAccountId,
      webhookVerifyToken: webhookVerifyToken ?? this.webhookVerifyToken,
      isConnected: isConnected ?? this.isConnected,
      connectedAt: connectedAt ?? this.connectedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      displayPhoneNumber: displayPhoneNumber ?? this.displayPhoneNumber,
      qualityRating: qualityRating ?? this.qualityRating,
    );
  }

  bool get hasCredentials =>
      phoneNumberId.isNotEmpty && accessToken.isNotEmpty;
}
