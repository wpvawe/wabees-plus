import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../datasources/firebase/firestore_ds.dart';
import '../datasources/api/whatsapp_api_ds.dart';
import '../models/whatsapp/whatsapp_config.dart';
import '../models/whatsapp/whatsapp_api_response.dart';

/// 📱 WHATSAPP REPOSITORY
class WhatsappRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  final WhatsappApiDs _api = WhatsappApiDs();

  // ============ GET CONFIG (REALTIME) ============
  Stream<WhatsappConfig> getConfigStream(String userId) {
    return _firestore.user(userId)
        .collection('whatsapp_config')
        .doc('config')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return WhatsappConfig.empty();
      return WhatsappConfig.fromJson(doc.data()!);
    });
  }

  // ============ GET CONFIG (ONE-TIME) ============
  // In-memory config cache — avoids Firestore read on every message send
  WhatsappConfig? _cachedConfig;
  String? _cachedConfigUserId;
  DateTime? _configCachedAt;
  static const _configCacheTtl = Duration(minutes: 5);

  Future<WhatsappConfig> getConfig(String userId) async {
    // Return cached if same user and not expired
    if (_cachedConfig != null &&
        _cachedConfigUserId == userId &&
        _configCachedAt != null &&
        DateTime.now().difference(_configCachedAt!) < _configCacheTtl) {
      return _cachedConfig!;
    }

    final doc = await _firestore.user(userId)
        .collection('whatsapp_config')
        .doc('config')
        .get();
    if (!doc.exists) return WhatsappConfig.empty();
    final config = WhatsappConfig.fromJson(doc.data()!);

    // Cache the result
    _cachedConfig = config;
    _cachedConfigUserId = userId;
    _configCachedAt = DateTime.now();

    return config;
  }

  /// Invalidate cached config (call after saving new config)
  void invalidateConfigCache() {
    _cachedConfig = null;
    _cachedConfigUserId = null;
    _configCachedAt = null;
  }

  // ============ SAVE CONFIG ============
  Future<void> saveConfig(String userId, WhatsappConfig config) async {
    await _firestore.user(userId)
        .collection('whatsapp_config')
        .doc('config')
        .set(config.toJson(), SetOptions(merge: true));
  }

  // ============ VERIFY & CONNECT ============
  Future<WhatsappApiResponse> verifyAndConnect({
    required String userId,
    required String phoneNumberId,
    required String accessToken,
    String businessAccountId = '',
  }) async {
    // 1. Call Hostinger proxy to verify with Meta API
    final result = await _api.verifyConnection(
      phoneNumberId: phoneNumberId,
      accessToken: accessToken,
    );

    if (result.success) {
      // Use user-provided WABA ID if available, otherwise use API-detected
      final wabaId = businessAccountId.isNotEmpty
          ? businessAccountId
          : (result.data?['business_account_id'] ?? '');

      // 2. Save config to Firestore
      final config = WhatsappConfig(
        phoneNumberId: phoneNumberId,
        accessToken: accessToken,
        businessAccountId: wabaId,
        isConnected: true,
        connectedAt: DateTime.now(),
        lastVerifiedAt: DateTime.now(),
        displayPhoneNumber: result.data?['display_phone_number'],
        qualityRating: result.data?['quality_rating'],
      );

      await saveConfig(userId, config);
      invalidateConfigCache(); // Clear cache so next getConfig reads fresh

      // CRITICAL: Subscribe app to Meta webhooks for this phone number.
      // Without this call, Meta does NOT deliver incoming messages to our webhook.
      // This must be called after every new number connection.
      try {
        final subResult = await _api.subscribeWebhook(
          phoneNumberId: phoneNumberId,
          accessToken: accessToken,
        );
        debugPrint('[WABEES] subscribeWebhook: ${subResult.success ? "OK" : "FAILED: ${subResult.message}"}');
      } catch (e) {
        debugPrint('[WABEES] subscribeWebhook exception (non-fatal): $e');
        // Non-fatal — connection still completes, user can reconnect if needed
      }

      // 3. Update user document
      await _firestore.user(userId).update({
        'whatsappPhoneNumberId': phoneNumberId,
        'whatsappAccessToken': accessToken,
        'whatsappConnected': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. dataOwner logic: check if someone already owns this WhatsApp number
      try {
        final waMapRef = FirebaseFirestore.instance
            .collection('wa_map')
            .doc(phoneNumberId);

        final waMapDoc = await waMapRef.get();
        String? existingOwnerId;

        if (waMapDoc.exists) {
          final data = waMapDoc.data() ?? {};
          existingOwnerId = data['ownerId'] as String?;
          // Also check old format userId field
          existingOwnerId ??= data['userId'] as String?;
        }

        if (existingOwnerId != null && existingOwnerId != userId) {
          // Another user owns this number => this user becomes an AGENT
          debugPrint('[WABEES] Owner detected: $existingOwnerId -> setting dataOwner for agent $userId');

          // Set dataOwner on this user's doc so app reads from owner's data
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'dataOwner': existingOwnerId,
          }, SetOptions(merge: true));

          // Register as agent under owner
          await FirebaseFirestore.instance
              .collection('users')
              .doc(existingOwnerId)
              .collection('agents')
              .doc(userId)
              .set({
            'email': FirebaseAuth.instance.currentUser?.email ?? '',
            'joinedAt': FieldValue.serverTimestamp(),
            'fcmToken': await FirebaseMessaging.instance.getToken(),
          }, SetOptions(merge: true));

          debugPrint('[WABEES] Agent $userId registered under owner $existingOwnerId');
        } else {
          // This user is the OWNER (first to connect, or reconnecting)
          await waMapRef.set({
            'userId': userId,   // webhook.php reads this field
            'ownerId': userId,  // keep alias for backward compat
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Clear dataOwner if was previously set (user is now owner)
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'dataOwner': FieldValue.delete(),
          }).catchError((_) {});

          debugPrint('[WABEES] Owner set: $userId for phoneNumberId=$phoneNumberId');
        }
      } catch (e) {
        debugPrint('[WABEES] ERROR: wa_map/dataOwner setup failed: $e');
      }

      // NOTE: Agents share the owner's data via dataOwner field.
    }

    return result;
  }


  // ============ DETECT: BUSINESSES ============
  Future<List<Map<String, dynamic>>> fetchBusinessesList({
    required String accessToken,
  }) async {
    try {
      final result = await _api.detectBusinesses(accessToken: accessToken);
      if (result.success && result.data != null) {
        final raw = result.data!['businesses'] as List? ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ============ DETECT: WABAs ============
  Future<List<Map<String, dynamic>>> fetchWabasList({
    required String accessToken,
    required String businessId,
  }) async {
    try {
      final result = await _api.detectWabas(
        accessToken: accessToken,
        businessId: businessId,
      );
      if (result.success && result.data != null) {
        final raw = result.data!['wabas'] as List? ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ============ DETECT: PHONE NUMBERS ============
  Future<List<Map<String, dynamic>>> fetchPhonesList({
    required String accessToken,
    required String wabaId,
  }) async {
    try {
      final result = await _api.detectPhones(
        accessToken: accessToken,
        wabaId: wabaId,
      );
      if (result.success && result.data != null) {
        final raw = result.data!['phones'] as List? ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ============ SMART CONNECT ============
  Future<Map<String, dynamic>?> smartConnect({
    required String accessToken,
    required String phoneNumberId,
  }) async {
    try {
      final result = await _api.smartConnect(
        accessToken: accessToken,
        phoneNumberId: phoneNumberId,
      );
      if (result.success && result.data != null) {
        return result.data!;
      }
    } catch (_) {}
    return null;
  }

  // ============ SAVE SETUP CONFIG ============
  Future<void> saveSetupConfig({
    required String userId,
    required String accessToken,
    required String phoneNumberId,
    required String wabaId,
  }) async {
    // Use verifyAndConnect which saves to Firestore
    await verifyAndConnect(
      userId: userId,
      phoneNumberId: phoneNumberId,
      accessToken: accessToken,
      businessAccountId: wabaId,
    );
  }

  // ============ DISCONNECT ============
  Future<void> disconnect(String userId) async {
    // Capture current phoneNumberId and dataOwner before clearing
    final existing = await getConfig(userId);
    final phoneId = existing.phoneNumberId;

    // Read this user's dataOwner field
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final dataOwner = userDoc.data()?['dataOwner'] as String?;
    final isAgent = dataOwner != null && dataOwner.isNotEmpty;

    // Clear WhatsApp config for this user
    final config = WhatsappConfig.empty().copyWith(isConnected: false);
    await saveConfig(userId, config);

    await _firestore.user(userId).update({
      'whatsappPhoneNumberId': null,
      'whatsappAccessToken': null,
      'whatsappConnected': false,
      'dataOwner': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (phoneId.isNotEmpty) {
      try {
        if (isAgent) {
          // AGENT disconnecting: remove from owner's agents subcollection
          // Do NOT touch wa_map — the owner's entry stays
          await FirebaseFirestore.instance
              .collection('users')
              .doc(dataOwner)
              .collection('agents')
              .doc(userId)
              .delete();
          debugPrint('[WABEES] Agent $userId removed from owner $dataOwner agents');
        } else {
          // OWNER disconnecting: check if there are agents
          final agentsSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('agents')
              .limit(1)
              .get();

          if (agentsSnap.docs.isEmpty) {
            // No agents — safe to delete wa_map doc
            await FirebaseFirestore.instance
                .collection('wa_map')
                .doc(phoneId)
                .delete();
            debugPrint('[WABEES] Owner $userId disconnected, wa_map deleted (no agents)');
          } else {
            // Has agents — owner disconnects but keeps ownership
            // wa_map keeps ownerId, owner can reconnect and still be owner
            debugPrint('[WABEES] Owner $userId disconnected but keeping ownership (agents exist)');
          }
        }
      } catch (e) {
        debugPrint('[WABEES] ERROR in disconnect cleanup: $e');
      }
    }
  }

  // ============ SEND TEXT ============
  Future<WhatsappApiResponse> sendText({
    required String userId,
    required String to,
    required String message,
    String? contextMessageId,
  }) async {
    // Smart config: owner first, fallback to agent's own
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    final result = await _api.sendTextMessage(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      to: to,
      message: message,
      contextMessageId: contextMessageId,
    );

    // Bug 6 fix: invalidate config cache on token expiry so next call fetches fresh token
    if (!result.success && _isTokenExpiredError(result)) {
      invalidateConfigCache();
    }

    return result;
  }

  // ============ SEND TEMPLATE ============
  Future<WhatsappApiResponse> sendTemplate({
    required String userId,
    required String to,
    required String templateName,
    required String languageCode,
    List<Map<String, dynamic>>? components,
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.sendTemplateMessage(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      to: to,
      templateName: templateName,
      languageCode: languageCode,
      components: components,
    );
  }

  // ============ SEND MEDIA ============
  Future<WhatsappApiResponse> sendMedia({
    required String userId,
    required String to,
    required String mediaType,
    required String mediaUrl,
    String? mediaId,
    String? caption,
    bool isVoice = false, // true for voice notes
    String? filename,
    String? contextMessageId,
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    final result = await _api.sendMediaMessage(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      to: to,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      mediaId: mediaId,
      caption: caption,
      isVoice: isVoice,
      filename: filename,
      contextMessageId: contextMessageId,
    );

    // Bug 6 fix: invalidate config cache on token expiry
    if (!result.success && _isTokenExpiredError(result)) {
      invalidateConfigCache();
    }

    return result;
  }

  /// Returns true if the API failure is due to an expired / invalid access token.
  /// When detected, the config cache is cleared so the next call reads a fresh token.
  bool _isTokenExpiredError(WhatsappApiResponse result) {
    final msg = (result.message ?? '').toLowerCase();
    return msg.contains('token') ||
        msg.contains('expired') ||
        msg.contains('oauth') ||
        msg.contains('unauthorized') ||
        msg.contains('invalid or expired') ||
        msg.contains('access token');
  }

  // ============ SEND TYPING INDICATOR ============
  Future<WhatsappApiResponse> sendTypingIndicator({
    required String userId,
    required String messageId,
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.sendTypingIndicator(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      messageId: messageId,
    );
  }

  // ============ SEND REACTION ============
  Future<WhatsappApiResponse> sendReaction({
    required String userId,
    required String to,
    required String messageId,
    required String emoji, // empty string removes reaction
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.sendReactionMessage(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      to: to,
      messageId: messageId,
      emoji: emoji,
    );
  }

  // ============ DELETE (UNSEND) MESSAGE ============
  Future<WhatsappApiResponse> deleteMessage({
    required String userId,
    required String whatsappMessageId,
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.deleteWhatsAppMessage(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      messageId: whatsappMessageId,
    );
  }

  // ============ GET TEMPLATES ============
  Future<WhatsappApiResponse> getTemplates(String userId) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials || config.businessAccountId.isEmpty) {
      return WhatsappApiResponse.error('WhatsApp not connected or Business Account ID missing');
    }

    return _api.getTemplates(
      businessAccountId: config.businessAccountId,
      accessToken: config.accessToken,
    );
  }
  // ============ GET INSIGHTS (Quality + Limits + Templates) ============
  Future<WhatsappApiResponse> getInsights(String userId) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.getInsights(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      businessAccountId: config.businessAccountId,
    );
  }

  // ============ GET MONTHLY ANALYTICS ============
  Future<WhatsappApiResponse> getAnalytics({
    required String userId,
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    if (config.businessAccountId.isEmpty) {
      return WhatsappApiResponse.error('Business account not configured');
    }

    final result = await _api.getAnalytics(
      businessAccountId: config.businessAccountId,
      accessToken: config.accessToken,
      phoneNumberId: config.phoneNumberId,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
    );
    
    if (result.success && result.data != null && result.data!['debug'] != null) {
      // Avoid noisy logs in release
      assert(() {
        // debug-only
        // ignore: avoid_print
        print('ANALYTICS DEBUG: ${result.data!['debug']}');
        return true;
      }());
    }
    
    return result;
  }

  // ============ CREATE TEMPLATE ON META ============

  Future<WhatsappApiResponse> createTemplateOnMeta({
    required String userId,
    required String name,
    required String category,
    required String language,
    required String body,
    String? header,
    String? footer,
    Map<String, String>? variableSamples,
    Map<String, String>? variableTypes,
    List<Map<String, dynamic>>? buttons,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials || config.businessAccountId.isEmpty) {
      return WhatsappApiResponse.error('WhatsApp not connected or Business Account ID missing');
    }

    return _api.createTemplate(
      businessAccountId: config.businessAccountId,
      accessToken: config.accessToken,
      name: name,
      category: category,
      language: language,
      body: body,
      header: header,
      footer: footer,
      variableSamples: variableSamples,
      variableTypes: variableTypes,
      buttons: buttons,
    );
  }

  // ============ EDIT TEMPLATE ON META ============
  Future<WhatsappApiResponse> editTemplateOnMeta({
    required String userId,
    required String templateId,
    required String body,
    String? header,
    String? footer,
    String? category,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.editTemplate(
      accessToken: config.accessToken,
      templateId: templateId,
      body: body,
      header: header,
      footer: footer,
      category: category,
    );
  }

  // ============ DELETE TEMPLATE ON META ============
  Future<WhatsappApiResponse> deleteTemplateOnMeta({
    required String userId,
    required String templateName,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials || config.businessAccountId.isEmpty) {
      return WhatsappApiResponse.error('WhatsApp not connected or Business Account ID missing');
    }

    return _api.deleteTemplate(
      businessAccountId: config.businessAccountId,
      accessToken: config.accessToken,
      templateName: templateName,
    );
  }

  // ============ MARK MESSAGE AS READ ============
  Future<WhatsappApiResponse> markMessageRead({
    required String userId,
    required String messageId,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.markMessageRead(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      messageId: messageId,
    );
  }

  // ============ PHONE HEALTH ============
  Future<WhatsappApiResponse> getPhoneHealth(String userId) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.getPhoneHealth(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
    );
  }

  // ============ BUSINESS PROFILE ============
  Future<WhatsappApiResponse> getBusinessProfile(String userId) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.getBusinessProfile(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
    );
  }

  Future<WhatsappApiResponse> updateBusinessProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.updateBusinessProfile(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      profileData: profileData,
    );
  }

  // ============ UPLOAD MEDIA ============
  Future<WhatsappApiResponse> uploadMedia({
    required String userId,
    required String filePath,
    required String mediaType,
  }) async {
    final config = await _resolveConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }
    return _api.uploadMedia(
      filePath: filePath,
      mediaType: mediaType,
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
    );
  }

  // ============ AUTO-DETECT CONNECTION STATUS ============
  Future<void> updateConnectionStatus(String userId, bool isConnected) async {
    await _firestore.user(userId)
        .collection('whatsapp_config')
        .doc('config')
        .update({
      'isConnected': isConnected,
      if (isConnected) 'lastVerifiedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.user(userId).update({
      'whatsappConnected': isConnected,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ MESSAGE LINKS (wa.me/message/XXX) ============
  Future<WhatsappApiResponse> getMessageLinks(String userId) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.getMessageLinks(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
    );
  }

  Future<WhatsappApiResponse> createMessageLink({
    required String userId,
    required String prefilledMessage,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.createMessageLink(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      prefilledMessage: prefilledMessage,
    );
  }

  Future<WhatsappApiResponse> deleteMessageLink({
    required String userId,
    required String linkId,
  }) async {
    final config = await getConfig(userId);
    if (!config.hasCredentials) {
      return WhatsappApiResponse.error('WhatsApp not connected');
    }

    return _api.deleteMessageLink(
      phoneNumberId: config.phoneNumberId,
      accessToken: config.accessToken,
      linkId: linkId,
    );
  }

  /// Resolve working WhatsApp config for sending:
  /// 1. Try owner's config (if user is an agent)
  /// 2. Fallback to user's own config (agent has valid credentials saved during connect)
  Future<WhatsappConfig> _resolveConfig(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final dataOwner = doc.data()?['dataOwner'] as String?;
      if (dataOwner != null && dataOwner.isNotEmpty) {
        // Try owner's config first
        final ownerConfig = await getConfig(dataOwner);
        if (ownerConfig.hasCredentials) return ownerConfig;
        // Owner disconnected — fallback to agent's own config
        final agentConfig = await getConfig(userId);
        if (agentConfig.hasCredentials) return agentConfig;
      }
    } catch (_) {}
    // Default: user's own config
    return getConfig(userId);
  }
}
