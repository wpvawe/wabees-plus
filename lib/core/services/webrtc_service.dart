import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 🎙️ WEBRTC SERVICE — Handles WebRTC peer connection for WhatsApp Calling API
///
/// Usage:
///   Outgoing call:
///     1. initialize() → createOffer() → send SDP to Meta API
///     2. Meta returns SDP answer → setRemoteAnswer(sdp)
///
///   Incoming call:
///     1. initialize() → createAnswer(remoteSdpOffer from Firestore)
///     2. Send SDP answer to Meta API (acceptCall)
class WebRTCService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _initialized = false;

  // Store local SDP ourselves for reliable ICE gathering across all platforms.
  RTCSessionDescription? _localDesc;

  // Collect ICE candidates for reliable gathering
  final List<RTCIceCandidate> _iceCandidates = [];

  /// ICE configuration with STUN + TURN servers.
  ///
  /// STUN servers discover your public IP on open networks.
  /// TURN servers RELAY traffic when both peers are behind symmetric NAT
  /// (very common on 3G/4G/5G mobile networks). Without TURN, calls
  /// between two mobile users on different carriers often fail.
  ///
  /// OpenRelay is a free public TURN server for development.
  /// For production replace with your own TURN server credentials
  /// (e.g. Twilio, Metered.ca, Coturn self-hosted).
  static const _iceConfig = {
    'iceServers': [
      // Google STUN (primary)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Cloudflare STUN (fast global coverage)
      {'urls': 'stun:stun.cloudflare.com:3478'},
      // OpenRelay public TURN — handles symmetric NAT on mobile networks
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turns:openrelay.metered.ca:443',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceCandidatePoolSize': 10,
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  static const _sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  bool get isInitialized => _initialized;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;

  // ============ INITIALIZE ============
  /// Request mic access and create peer connection.
  /// Call this before createOffer() or createAnswer().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request mic (audio only — no video for voice calls)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      // Create peer connection
      _pc = await createPeerConnection(_iceConfig);

      // Register onIceCandidate BEFORE setting local description
      // so we don't miss early candidates
      _pc!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          _iceCandidates.add(candidate);
          debugPrint('[WebRTC] ICE candidate gathered '
              '(total: ${_iceCandidates.length})');
        }
      };

      // Add local audio tracks to peer connection
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
        debugPrint('[WebRTC] Added audio track: ${track.id}');
      }

      _initialized = true;
      debugPrint('[WebRTC] ✅ Initialized — '
          '${_localStream!.getAudioTracks().length} audio track(s)');
    } catch (e) {
      debugPrint('[WebRTC] ❌ initialize() failed: $e');
      rethrow;
    }
  }

  // ============ CREATE OFFER (Outgoing call) ============
  /// Generate SDP offer. Returns the full SDP string after ICE gathering.
  Future<String> createOffer() async {
    _assertInitialized('createOffer');
    _iceCandidates.clear();
    _localDesc = null;

    final offer = await _pc!.createOffer(_sdpConstraints);
    _localDesc = offer;
    await _pc!.setLocalDescription(offer);

    final sdp = await _gatherIce();
    debugPrint('[WebRTC] ✅ SDP offer ready (${sdp.length} chars)');
    return sdp;
  }

  // ============ CREATE ANSWER (Incoming call) ============
  /// Process remote SDP offer from Meta (stored in Firestore), generate answer.
  /// Returns SDP answer string to send to Meta via acceptCall().
  Future<String> createAnswer(String remoteSdpOffer) async {
    _assertInitialized('createAnswer');
    _iceCandidates.clear();
    _localDesc = null;

    await _pc!.setRemoteDescription(
      RTCSessionDescription(remoteSdpOffer, 'offer'),
    );

    final answer = await _pc!.createAnswer(_sdpConstraints);
    _localDesc = answer;
    await _pc!.setLocalDescription(answer);

    final sdp = await _gatherIce();
    debugPrint('[WebRTC] ✅ SDP answer ready (${sdp.length} chars)');
    return sdp;
  }

  // ============ SET REMOTE ANSWER (Outgoing call, after Meta responds) ============
  /// Apply Meta's SDP answer to complete outgoing call negotiation.
  Future<void> setRemoteAnswer(String sdpAnswer) async {
    if (_pc == null) return;
    try {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdpAnswer, 'answer'),
      );
      debugPrint('[WebRTC] ✅ Remote SDP answer applied');
    } catch (e) {
      debugPrint('[WebRTC] ❌ setRemoteAnswer failed: $e');
    }
  }

  // ============ ICE GATHERING ============
  /// Wait for ICE gathering to finish (or timeout), return full local SDP.
  /// Uses onIceGatheringState callback + candidate-idle timeout fallback.
  Future<String> _gatherIce() async {
    final completer = Completer<String>();

    // Strategy 1: onIceGatheringState — fires when all candidates gathered
    _pc!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('[WebRTC] ICE gathering state: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete(_localDesc?.sdp ?? '');
      }
    };

    // Strategy 2: onConnectionState — complete early if peer connected
    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          !completer.isCompleted) {
        completer.complete(_localDesc?.sdp ?? '');
      }
    };

    // Strategy 3: Candidate-idle timeout — if no new candidates for 1.5s,
    // assume gathering is done (common on mobile with good network)
    _watchCandidateIdle(completer);

    // Hard timeout — use whatever SDP we have rather than hanging forever
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[WebRTC] ⚠️ ICE hard timeout '
            '(${_iceCandidates.length} candidates) — using stored SDP');
        return _localDesc?.sdp ?? '';
      },
    );
  }

  /// Poll every 300ms — if candidate count stops growing for 1.5s, we're done.
  void _watchCandidateIdle(Completer<String> completer) async {
    int lastCount = -1;
    int idleMs = 0;
    const pollMs = 300;
    const idleThresholdMs = 1500;

    while (!completer.isCompleted) {
      await Future<void>.delayed(const Duration(milliseconds: pollMs));
      if (completer.isCompleted) break;

      final current = _iceCandidates.length;
      if (current > 0 && current == lastCount) {
        idleMs += pollMs;
        if (idleMs >= idleThresholdMs) {
          debugPrint('[WebRTC] ICE idle ($current candidates, '
              '${idleMs}ms idle) — completing');
          if (!completer.isCompleted) {
            completer.complete(_localDesc?.sdp ?? '');
          }
          break;
        }
      } else {
        idleMs = 0;
        lastCount = current;
      }
    }
  }

  // ============ MUTE TOGGLE ============
  /// Toggle microphone mute. Returns new muted state.
  bool toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    debugPrint('[WebRTC] Mute → $_isMuted');
    return _isMuted;
  }

  // ============ SPEAKER TOGGLE ============
  /// Toggle loudspeaker. Returns new speaker state.
  Future<bool> toggleSpeaker() async {
    _isSpeaker = !_isSpeaker;
    try {
      await Helper.setSpeakerphoneOn(_isSpeaker);
    } catch (e) {
      // Helper.setSpeakerphoneOn is Android-only; ignore on other platforms
      debugPrint('[WebRTC] setSpeakerphoneOn error (non-fatal): $e');
    }
    debugPrint('[WebRTC] Speaker → $_isSpeaker');
    return _isSpeaker;
  }

  // ============ DISPOSE ============
  /// Release all media resources and close the peer connection.
  Future<void> dispose() async {
    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      await _localStream?.dispose();
      await _pc?.close();
      await _pc?.dispose();
    } catch (e) {
      debugPrint('[WebRTC] dispose error (non-fatal): $e');
    } finally {
      _pc = null;
      _localStream = null;
      _localDesc = null;
      _iceCandidates.clear();
      _initialized = false;
      debugPrint('[WebRTC] ✅ Disposed');
    }
  }

  void _assertInitialized(String method) {
    if (!_initialized || _pc == null) {
      throw StateError('[WebRTC] $method() called before initialize()');
    }
  }
}
