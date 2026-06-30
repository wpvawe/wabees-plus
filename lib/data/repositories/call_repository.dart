import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../datasources/firebase/firestore_ds.dart';
import '../../core/utils/phone_utils.dart';

/// 📞 CALL REPOSITORY — WhatsApp Business Calling API
/// Uses same config resolution as WhatsappRepository (supports dataOwner/agents)
class CallRepository {
  final FirestoreDs _firestore = FirestoreDs.instance;
  static const _apiVersion = 'v22.0';

  // ============ RESOLVE CONFIG (handles dataOwner/agent pattern) ============
  Future<Map<String, String>> _resolveConfig(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final dataOwner = userDoc.data()?['dataOwner'] as String?;
    final ownerId =
        (dataOwner != null && dataOwner.isNotEmpty) ? dataOwner : userId;

    final configDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('whatsapp_config')
        .doc('config')
        .get();

    final data = configDoc.data();
    if (data == null) {
      final accessToken =
          userDoc.data()?['whatsappAccessToken'] as String? ?? '';
      final phoneNumberId =
          userDoc.data()?['whatsappPhoneNumberId'] as String? ?? '';
      return {
        'accessToken': accessToken,
        'phoneNumberId': phoneNumberId,
        'ownerId': ownerId,
      };
    }

    return {
      'accessToken': data['accessToken'] as String? ?? '',
      'phoneNumberId': data['phoneNumberId'] as String? ?? '',
      'ownerId': ownerId,
    };
  }

  // ============ CALL LOGS (REALTIME) ============
  Stream<List<CallLog>> getCallLogs(String userId) async* {
    String ownerId = userId;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final dataOwner = userDoc.data()?['dataOwner'] as String?;
      if (dataOwner != null && dataOwner.isNotEmpty) {
        ownerId = dataOwner;
      }
    } catch (_) {}

    yield* _firestore
        .user(ownerId)
        .collection('call_logs')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          final logs = <CallLog>[];
          for (final doc in snap.docs) {
            try {
              logs.add(CallLog.fromJson(doc.data(), doc.id));
            } catch (_) {
              // Skip malformed documents
            }
          }
          return logs;
        });
  }

  // ============ REALTIME CALL STATUS STREAM ============
  Stream<Map<String, dynamic>?> watchCallStatus(
      String ownerId, String callId) {
    return _firestore
        .user(ownerId)
        .collection('call_logs')
        .doc(callId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // ============ FETCH CALL DOCUMENT (for sdpOffer on incoming calls) ============
  /// Reads the call_logs/{callId} document from Firestore.
  /// webhook.php stores 'sdpOffer' here when Meta signals an incoming call.
  Future<Map<String, dynamic>?> getCallDocument(
      String ownerId, String callId) async {
    try {
      final doc = await _firestore
          .user(ownerId)
          .collection('call_logs')
          .doc(callId)
          .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('[CALL] getCallDocument error: $e');
      return null;
    }
  }

  // ============ CHECK CALL PERMISSIONS ============
  Future<Map<String, dynamic>> checkCallPermission({
    required String userId,
    required String contactPhone,
  }) async {
    try {
      final config = await _resolveConfig(userId);
      final accessToken = config['accessToken']!;
      final phoneNumberId = config['phoneNumberId']!;

      if (accessToken.isEmpty || phoneNumberId.isEmpty) {
        return {'canCall': false, 'reason': 'WhatsApp not configured'};
      }

      final phone = contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse(
          'https://graph.facebook.com/$_apiVersion/$phoneNumberId/call_permissions?to=$phone');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $accessToken',
      });

      debugPrint(
          '[CALL] checkPermission HTTP=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final permissions = data['data'] as List? ?? [];
        if (permissions.isEmpty) {
          return {'canCall': false, 'reason': 'Call permission not granted'};
        }
        final first = permissions.first as Map<String, dynamic>;
        final canCall = first['can_call'] == true ||
            first['status'] == 'granted' ||
            first['permission'] == 'granted';
        return {'canCall': canCall, 'data': data};
      } else {
        final data = jsonDecode(response.body);
        final errorMsg =
            data['error']?['message'] ?? 'Permission check failed';
        final errorCode = data['error']?['code'] ?? 0;

        // Error 100/33/10 = endpoint not available — try calling directly
        if (errorCode == 100 || errorCode == 33 || errorCode == 10) {
          return {
            'canCall': true,
            'reason': 'Permission check not available, attempting call directly'
          };
        }
        return {'canCall': false, 'reason': errorMsg};
      }
    } catch (e) {
      debugPrint('[CALL] checkPermission error: $e');
      // On network error, allow trying the call
      return {'canCall': true, 'reason': 'Permission check failed: $e'};
    }
  }

  // ============ REQUEST CALL PERMISSION ============
  Future<bool> requestCallPermission({
    required String userId,
    required String contactPhone,
    String? message,
  }) async {
    try {
      final config = await _resolveConfig(userId);
      final accessToken = config['accessToken']!;
      final phoneNumberId = config['phoneNumberId']!;
      final ownerId = config['ownerId']!;

      if (accessToken.isEmpty || phoneNumberId.isEmpty) return false;

      final phone = contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse(
          'https://graph.facebook.com/$_apiVersion/$phoneNumberId/messages');
      final response = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'messaging_product': 'whatsapp',
            'to': phone,
            'type': 'interactive',
            'interactive': {
              'type': 'call_permission_request',
              'body': {
                'text': message ??
                    'We would like to call you. Please grant permission for voice calls.',
              },
            },
          }));

      debugPrint(
          '[CALL] requestPermission HTTP=${response.statusCode} body=${response.body}');

      final logId = 'perm_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.user(ownerId).collection('call_logs').doc(logId).set({
        'type': 'permission_request',
        'to': PhoneUtils.normalize(contactPhone),
        'status': response.statusCode == 200 ? 'requested' : 'failed',
        'error': response.statusCode != 200 ? response.body : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CALL] requestPermission error: $e');
      return false;
    }
  }

  // ============ INITIATE OUTBOUND CALL ============
  Future<Map<String, dynamic>> initiateCall({
    required String userId,
    required String contactPhone,
    required String contactName,
    String? sdpOffer,
    String callType = 'voice',
  }) async {
    try {
      final config = await _resolveConfig(userId);
      final accessToken = config['accessToken']!;
      final phoneNumberId = config['phoneNumberId']!;
      final ownerId = config['ownerId']!;

      if (accessToken.isEmpty || phoneNumberId.isEmpty) {
        return {'success': false, 'error': 'WhatsApp not configured'};
      }

      final phone = contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse(
          'https://graph.facebook.com/$_apiVersion/$phoneNumberId/calls');

      // FIX: 'messaging_product' is required at root, 'action' is required,
      // SDP must go inside 'session' object (not at root level).
      final body = <String, dynamic>{
        'messaging_product': 'whatsapp',
        'action': 'connect',
        'to': phone,
        'call_type': callType,
      };
      if (sdpOffer != null && sdpOffer.isNotEmpty) {
        body['session'] = {'sdp': sdpOffer};
      }

      debugPrint('[CALL] initiateCall to=$phone body=${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body));

      debugPrint(
          '[CALL] initiateCall HTTP=${response.statusCode} body=${response.body}');

      final data = jsonDecode(response.body);

      final callId = data['call_id'] ??
          'call_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.user(ownerId).collection('call_logs').doc(callId).set({
        'callId': callId,
        'to': PhoneUtils.normalize(contactPhone),
        'contactName': contactName,
        'type': 'outgoing',
        'callType': callType,
        'status': (response.statusCode == 200 || response.statusCode == 201)
            ? 'connecting'
            : 'failed',
        'error':
            (response.statusCode != 200 && response.statusCode != 201)
                ? (data['error']?['message'] ?? response.body)
                : null,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .user(ownerId)
          .collection('conversations')
          .doc(PhoneUtils.normalize(contactPhone))
          .set({
        'lastMessage': '📞 Outgoing call',
        'lastMessageType': 'call',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'callId': callId,
          'ownerId': ownerId,
          'data': data
        };
      } else {
        final errorMsg =
            data['error']?['message'] ?? 'Call failed (HTTP ${response.statusCode})';
        return {'success': false, 'error': errorMsg, 'data': data};
      }
    } catch (e) {
      debugPrint('[CALL] initiateCall error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============ ACCEPT INCOMING CALL ============
  Future<bool> acceptCall({
    required String userId,
    required String callId,
    String? sdpAnswer,
  }) async {
    try {
      final config = await _resolveConfig(userId);
      final accessToken = config['accessToken']!;
      final phoneNumberId = config['phoneNumberId']!;
      final ownerId = config['ownerId']!;

      if (accessToken.isEmpty || phoneNumberId.isEmpty) return false;

      final url = Uri.parse(
          'https://graph.facebook.com/$_apiVersion/$phoneNumberId/calls');

      // FIX: 'messaging_product' is REQUIRED for accept action too.
      // Missing this caused Meta to return an error and the call was never accepted.
      final body = <String, dynamic>{
        'messaging_product': 'whatsapp',
        'action': 'accept',
        'call_id': callId,
      };
      if (sdpAnswer != null && sdpAnswer.isNotEmpty) {
        body['session'] = {'sdp': sdpAnswer};
      }

      debugPrint('[CALL] acceptCall callId=$callId body=${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body));

      debugPrint(
          '[CALL] acceptCall HTTP=${response.statusCode} body=${response.body}');

      final success =
          response.statusCode == 200 || response.statusCode == 201;

      // Update call log — only mark connected if API accepted
      await _firestore.user(ownerId).collection('call_logs').doc(callId).set({
        'status': success ? 'connected' : 'failed',
        'connectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return success;
    } catch (e) {
      debugPrint('[CALL] acceptCall error: $e');
      return false;
    }
  }

  // ============ REJECT / TERMINATE CALL ============
  Future<bool> endCall({
    required String userId,
    required String callId,
    String action = 'terminate', // 'reject' or 'terminate'
  }) async {
    try {
      final config = await _resolveConfig(userId);
      final accessToken = config['accessToken']!;
      final phoneNumberId = config['phoneNumberId']!;
      final ownerId = config['ownerId']!;

      if (accessToken.isEmpty || phoneNumberId.isEmpty) return false;

      final url = Uri.parse(
          'https://graph.facebook.com/$_apiVersion/$phoneNumberId/calls');

      // FIX: 'messaging_product' is required for reject/terminate too.
      // Without it, Meta API returns an error and the call is never ended properly.
      final response = await http.post(url,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'messaging_product': 'whatsapp',
            'action': action,
            'call_id': callId,
          }));

      debugPrint(
          '[CALL] endCall action=$action HTTP=${response.statusCode} body=${response.body}');

      await _firestore.user(ownerId).collection('call_logs').doc(callId).set({
        'status': action == 'reject' ? 'rejected' : 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[CALL] endCall error: $e');
      return false;
    }
  }
}

// ============ CALL LOG MODEL ============
class CallLog {
  final String id;
  final String callId;
  final String contactPhone;
  final String contactName;
  final String type;
  final String callType;
  final String status;
  final int duration;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  CallLog({
    required this.id,
    required this.callId,
    required this.contactPhone,
    required this.contactName,
    required this.type,
    required this.callType,
    required this.status,
    required this.duration,
    required this.createdAt,
    this.connectedAt,
    this.endedAt,
  });

  factory CallLog.fromJson(Map<String, dynamic> json, String id) {
    String extractString(dynamic val) {
      if (val == null) return '';
      if (val is String) return val;
      if (val is Map) {
        return val['stringValue']?.toString() ??
            val['integerValue']?.toString() ??
            val.values.first?.toString() ??
            '';
      }
      return val.toString();
    }

    int parseDuration(dynamic val) {
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is Map) {
        final v =
            val['integerValue'] ?? val['stringValue'] ?? val.values.first;
        return int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    }

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
      if (val is Map) {
        final tv = val['timestampValue'];
        if (tv is String) return DateTime.tryParse(tv);
      }
      return null;
    }

    final from = extractString(json['from']);
    final to = extractString(json['to']);
    final callerName = extractString(json['callerName']);
    final contactName = extractString(json['contactName']);

    return CallLog(
      id: id,
      callId: extractString(json['callId']).isNotEmpty
          ? extractString(json['callId'])
          : id,
      contactPhone: from.isNotEmpty ? from : to,
      contactName: callerName.isNotEmpty
          ? callerName
          : (contactName.isNotEmpty
              ? contactName
              : (from.isNotEmpty ? from : to)),
      type: extractString(json['type']).isNotEmpty
          ? extractString(json['type'])
          : 'unknown',
      callType: extractString(json['callType']).isNotEmpty
          ? extractString(json['callType'])
          : 'voice',
      status: extractString(json['status']).isNotEmpty
          ? extractString(json['status'])
          : 'unknown',
      duration: parseDuration(json['duration']),
      createdAt: parseTimestamp(json['createdAt']) ?? DateTime.now(),
      connectedAt: parseTimestamp(json['connectedAt']),
      endedAt: parseTimestamp(json['endedAt']),
    );
  }

  String get durationFormatted {
    if (duration <= 0) return '';
    final m = (duration ~/ 60).toString().padLeft(2, '0');
    final s = (duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get isMissed => status == 'missed' || status == 'not_answered';
  bool get isIncoming => type == 'incoming';
  bool get isOutgoing => type == 'outgoing';
}
