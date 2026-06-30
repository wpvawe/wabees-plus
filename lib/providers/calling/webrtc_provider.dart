import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/webrtc_service.dart';

/// Holds the active WebRTCService instance during a call.
/// Set before navigating to InCallScreen (outgoing calls).
/// Cleared by InCallScreen on dispose.
final activeWebRTCProvider = StateProvider<WebRTCService?>((ref) => null);
