import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/calling/incoming_call_provider.dart';

/// 📞 INCOMING CALL OVERLAY
/// WhatsApp-style floating call banner that appears on ANY screen
/// without navigating away. Slides in from top.
///
/// Used via MaterialApp builder — sits above GoRouter pages.
class IncomingCallOverlay extends ConsumerStatefulWidget {
  final IncomingCallData data;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallOverlay({
    super.key,
    required this.data,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  ConsumerState<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Auto-dismiss after 45 seconds if user ignores
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    _slideController.forward();

    // Vibrate on incoming call
    HapticFeedback.heavyImpact();

    // Auto-dismiss after 45s (call not answered)
    _autoDismissTimer = Timer(const Duration(seconds: 45), () {
      if (mounted) widget.onDecline();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _dismiss(VoidCallback callback) async {
    _autoDismissTimer?.cancel();
    await _slideController.reverse();
    callback();
  }

  String get _initials {
    final name = widget.data.callerName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.data.callType == 'video';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: GestureDetector(
              // Swipe up to dismiss (decline)
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                  _dismiss(widget.onDecline);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1A2E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF25D366).withAlpha(60),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Avatar with pulse ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, __) {
                          final ringSize = 52.0 + (_pulseController.value * 6);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse ring
                              Container(
                                width: ringSize,
                                height: ringSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF25D366).withAlpha(
                                      (80 * (1 - _pulseController.value)).toInt(),
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Avatar
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _initials,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(width: 12),

                      // Call info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.data.callerName.isNotEmpty
                                  ? widget.data.callerName
                                  : widget.data.callerPhone,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                                  size: 13,
                                  color: const Color(0xFF25D366),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Incoming WhatsApp ${isVideo ? 'Video' : 'Voice'} Call',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(160),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Decline button
                      _OverlayActionButton(
                        icon: Icons.call_end_rounded,
                        color: Colors.red,
                        label: 'Decline',
                        onTap: () => _dismiss(widget.onDecline),
                      ),

                      const SizedBox(width: 10),

                      // Accept button
                      _OverlayActionButton(
                        icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: const Color(0xFF25D366),
                        label: 'Accept',
                        onTap: () => _dismiss(widget.onAccept),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _OverlayActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
