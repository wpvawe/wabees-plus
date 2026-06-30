import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/calling/webrtc_provider.dart';

/// 📞 IN-CALL SCREEN — Active voice call with real WebRTC audio
///
/// Outgoing call flow:
///   1. Receives pre-created WebRTCService from activeWebRTCProvider
///   2. If sdpAnswer provided (from Meta API response), applies it immediately
///   3. Listens to Firestore for status changes
///
/// Incoming call flow:
///   1. Creates a fresh WebRTCService
///   2. Reads sdpOffer from Firestore call_logs (stored by webhook.php)
///   3. User taps Accept → createAnswer(sdpOffer) → sends to Meta
class InCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String contactName;
  final String contactPhone;
  final bool isIncoming;
  final String? ownerId;
  final String? sdpAnswer; // SDP answer from Meta (outgoing calls only)

  const InCallScreen({
    super.key,
    required this.callId,
    required this.contactName,
    required this.contactPhone,
    this.isIncoming = false,
    this.ownerId,
    this.sdpAnswer,
  });

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen>
    with TickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  bool _isEnding = false;
  bool _isAccepting = false;
  Duration _callDuration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseController;
  StreamSubscription<Map<String, dynamic>?>? _statusSub;
  String _statusLabel = '';

  WebRTCService? _webrtc;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _statusLabel = widget.isIncoming ? 'Incoming call...' : 'Connecting...';

    // Keep screen on during call
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _listenToCallStatus();
      if (!widget.isIncoming) {
        _setupOutgoingWebRTC();
      }
      // Incoming: WebRTC setup happens when user taps Accept
    });
  }

  // ============ OUTGOING CALL — apply SDP answer from Meta ============
  void _setupOutgoingWebRTC() async {
    // Re-use the WebRTCService created by the calling screen (stored in provider)
    final existing = ref.read(activeWebRTCProvider);
    if (existing != null) {
      _webrtc = existing;
      debugPrint('[INCALL] Using pre-initialized WebRTC from calling screen');
    }

    // Apply Meta's SDP answer if provided
    final sdpAnswer = widget.sdpAnswer;
    if (_webrtc != null && sdpAnswer != null && sdpAnswer.isNotEmpty) {
      await _webrtc!.setRemoteAnswer(sdpAnswer);
      debugPrint('[INCALL] ✅ Remote SDP answer applied — audio active');
    }
  }

  // ============ FIRESTORE STATUS LISTENER ============
  void _listenToCallStatus() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final resolvedOwnerId = widget.ownerId ?? user.dataOwner ?? user.id;

    _statusSub = CallRepository()
        .watchCallStatus(resolvedOwnerId, widget.callId)
        .listen((data) {
      if (data == null || !mounted) return;

      String extractString(dynamic val) {
        if (val is String) return val;
        if (val is Map) return val['stringValue']?.toString() ?? '';
        return '';
      }

      final status = extractString(data['status']);
      debugPrint('[INCALL] Firestore status: $status');

      if (!mounted) return;
      setState(() {
        switch (status) {
          case 'connected':
            if (!_isConnected) {
              _isConnected = true;
              _isAccepting = false;
              _statusLabel = '';
              _startTimer();
            }
          case 'ended':
          case 'terminated':
            _statusLabel = 'Call ended';
          case 'missed':
          case 'not_answered':
            _statusLabel = 'No answer';
          case 'rejected':
            _statusLabel = 'Call declined';
          case 'ringing':
            _statusLabel = 'Ringing...';
          case 'connecting':
            _statusLabel = 'Connecting...';
          default:
            if (status.isNotEmpty) _statusLabel = status;
        }
      });

      // Auto-close if call ended remotely
      if (['ended', 'terminated', 'missed', 'not_answered', 'rejected']
          .contains(status)) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }, onError: (e) {
      debugPrint('[INCALL] Firestore listen error: $e');
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusSub?.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Dispose WebRTC resources and clear provider
    _webrtc?.dispose();
    Future.microtask(() {
      try {
        ref.read(activeWebRTCProvider.notifier).state = null;
      } catch (_) {}
    });
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  // ============ MUTE TOGGLE — wired to actual WebRTC track ============
  void _toggleMute() {
    if (_webrtc != null) {
      final newMuted = _webrtc!.toggleMute();
      setState(() => _isMuted = newMuted);
    } else {
      setState(() => _isMuted = !_isMuted);
    }
    HapticFeedback.mediumImpact();
  }

  // ============ SPEAKER TOGGLE — wired to actual audio output ============
  void _toggleSpeaker() async {
    if (_webrtc != null) {
      final newSpeaker = await _webrtc!.toggleSpeaker();
      if (mounted) setState(() => _isSpeaker = newSpeaker);
    } else {
      setState(() => _isSpeaker = !_isSpeaker);
    }
    HapticFeedback.mediumImpact();
  }

  // ============ END CALL ============
  void _endCall() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    HapticFeedback.heavyImpact();

    final user = ref.read(currentUserProvider);
    if (user != null) {
      final resolvedOwnerId = widget.ownerId ?? user.dataOwner ?? user.id;
      await CallRepository().endCall(
        userId: resolvedOwnerId,
        callId: widget.callId,
        action: widget.isIncoming && !_isConnected ? 'reject' : 'terminate',
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ============ ACCEPT INCOMING CALL ============
  /// 1. Initialize WebRTC (request mic access)
  /// 2. Read sdpOffer from Firestore (stored by webhook.php at line 1530)
  /// 3. Generate SDP answer
  /// 4. Send answer to Meta via acceptCall()
  void _acceptIncomingCall() async {
    if (_isAccepting) return;
    setState(() {
      _isAccepting = true;
      _statusLabel = 'Connecting...';
    });
    HapticFeedback.mediumImpact();

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _isAccepting = false;
        _statusLabel = 'Auth error';
      });
      return;
    }

    final resolvedOwnerId = widget.ownerId ?? user.dataOwner ?? user.id;

    // Step 1 & 2: Initialize WebRTC + generate SDP answer
    String? sdpAnswer;
    try {
      _webrtc = WebRTCService();
      await _webrtc!.initialize();

      // Read sdpOffer from Firestore call_logs (webhook.php stores it)
      final callDoc = await CallRepository()
          .getCallDocument(resolvedOwnerId, widget.callId);
      final rawSdp = callDoc?['sdpOffer'];
      final sdpOffer = rawSdp is String && rawSdp.isNotEmpty ? rawSdp : null;

      if (sdpOffer != null) {
        sdpAnswer = await _webrtc!.createAnswer(sdpOffer);
        debugPrint('[INCALL] ✅ SDP answer generated from Meta offer');
      } else {
        debugPrint('[INCALL] No sdpOffer in Firestore — accepting without SDP');
      }
    } catch (e) {
      debugPrint('[INCALL] WebRTC setup error (non-fatal): $e');
      // Still attempt API accept — call may partially work
    }

    // Step 3: Tell Meta we accept
    final success = await CallRepository().acceptCall(
      userId: resolvedOwnerId,
      callId: widget.callId,
      sdpAnswer: sdpAnswer,
    );

    debugPrint('[INCALL] acceptCall API result: $success');

    if (success && mounted) {
      setState(() {
        _isConnected = true;
        _isAccepting = false;
        _statusLabel = '';
      });
      _startTimer();
    } else if (!success && mounted) {
      setState(() {
        _isAccepting = false;
        _statusLabel = 'Connection failed';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1426),
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1426),
              Color(0xFF162240),
              Color(0xFF0B1426),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Status / Timer
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final label = _isConnected
                      ? _formatDuration(_callDuration)
                      : _statusLabel.isNotEmpty
                          ? _statusLabel
                          : (widget.isIncoming
                              ? 'Incoming call...'
                              : 'Connecting...');
                  return Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: _isConnected
                          ? const Color(0xFF25D366)
                          : Colors.white.withAlpha(
                              (150 + (105 * _pulseController.value)).toInt()),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'WhatsApp Voice Call',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(80),
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(flex: 1),

              // Avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final scale = _isConnected
                      ? 1.0
                      : 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF25D366).withAlpha(180),
                            const Color(0xFF128C7E),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366)
                                .withAlpha(_isConnected ? 30 : 60),
                            blurRadius: _isConnected ? 20 : 40,
                            spreadRadius: _isConnected ? 5 : 15,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.contactName.isNotEmpty
                              ? widget.contactName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              Text(
                widget.contactName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.contactPhone,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(120),
                ),
              ),

              const Spacer(flex: 2),

              // Mute / Speaker — only shown when connected
              if (_isConnected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CallButton(
                        icon: _isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        isActive: _isMuted,
                        onTap: _toggleMute,
                      ),
                      _CallButton(
                        icon: _isSpeaker
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                        label: _isSpeaker ? 'Speaker On' : 'Speaker',
                        isActive: _isSpeaker,
                        onTap: _toggleSpeaker,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Accept/Decline or End Call
              if (widget.isIncoming && !_isConnected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _EndCallButton(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      color: Colors.red,
                      onTap: _isAccepting ? null : _endCall,
                    ),
                    _EndCallButton(
                      icon: Icons.call_rounded,
                      label: _isAccepting ? 'Connecting...' : 'Accept',
                      color: const Color(0xFF25D366),
                      onTap: _isAccepting ? null : _acceptIncomingCall,
                    ),
                  ],
                ),
              ] else ...[
                _EndCallButton(
                  icon: Icons.call_end_rounded,
                  label: _isEnding ? 'Ending...' : 'End Call',
                  color: Colors.red,
                  onTap: _endCall,
                ),
              ],

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ CALL CONTROL BUTTON ============
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withAlpha(30)
                  : Colors.white.withAlpha(10),
              border: Border.all(
                color: isActive
                    ? Colors.white.withAlpha(60)
                    : Colors.white.withAlpha(20),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withAlpha(180),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(150),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ END CALL BUTTON ============
class _EndCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _EndCallButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap == null ? color.withAlpha(100) : color,
              boxShadow: onTap == null
                  ? []
                  : [
                      BoxShadow(
                        color: color.withAlpha(80),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withAlpha(180),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
