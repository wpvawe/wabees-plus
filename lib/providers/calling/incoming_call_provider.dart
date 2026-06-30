import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 📞 INCOMING CALL STATE — holds data for the floating call overlay
class IncomingCallData {
  final String callId;
  final String callerName;
  final String callerPhone;
  final String callType; // voice / video
  final String? ownerId;

  const IncomingCallData({
    required this.callId,
    required this.callerName,
    required this.callerPhone,
    this.callType = 'voice',
    this.ownerId,
  });
}

/// Provider that holds the active incoming call (null = no incoming call)
/// Set to non-null when FCM incoming_call arrives.
/// Set back to null when user accepts or declines.
final incomingCallProvider = StateProvider<IncomingCallData?>((ref) => null);
