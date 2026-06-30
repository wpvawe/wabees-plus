import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'providers/theme/theme_provider.dart';
import 'providers/calling/incoming_call_provider.dart';
import 'screens/shared/calling/incoming_call_overlay.dart';
import 'data/repositories/call_repository.dart';
import 'providers/auth/auth_provider.dart';

/// 🚀 ROOT WIDGET — Converted to ConsumerStatefulWidget so we can safely
/// call consumePendingNavigation() exactly ONCE in initState (not on every build).
class WabeesApp extends ConsumerStatefulWidget {
  const WabeesApp({super.key});

  @override
  ConsumerState<WabeesApp> createState() => _WabeesAppState();
}

class _WabeesAppState extends ConsumerState<WabeesApp> {
  @override
  void initState() {
    super.initState();
    // FIX: Process pending navigation from terminated/background state exactly ONCE,
    // not on every build() call as it was before.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNavigation();
    });
  }

  void _processPendingNavigation() {
    final pending = NotificationService.instance.consumePendingNavigation();
    if (pending == null) return;

    final type = pending['type'] as String? ?? '';
    final router = ref.read(appRouterProvider);

    if (type == 'incoming_call') {
      // FIX: Show overlay instead of navigating away
      final callId = pending['callId'] as String? ?? '';
      if (callId.isNotEmpty) {
        ref.read(incomingCallProvider.notifier).state = IncomingCallData(
          callId: callId,
          callerName: pending['callerName'] as String? ?? '',
          callerPhone: pending['callerPhone'] as String? ?? '',
          callType: pending['callType'] as String? ?? 'voice',
        );
      }
    } else if ((pending['phone'] as String?)?.isNotEmpty == true) {
      router.push('/chat/${pending['phone']}');
    }
  }

  void _declineCall(IncomingCallData callData) async {
    // Dismiss overlay first
    ref.read(incomingCallProvider.notifier).state = null;

    // Tell Meta API to reject the call
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final ownerId = user.dataOwner ?? user.id;
        await CallRepository().endCall(
          userId: ownerId,
          callId: callData.callId,
          action: 'reject',
        );
      }
    } catch (e) {
      debugPrint('[OVERLAY] Decline call error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    // Wire notification tap → chat navigation
    NotificationService.onTapNavigate = (phone) {
      router.push('/chat/$phone');
    };

    // FIX: Wire incoming call FCM → show overlay (NOT navigate away!)
    // We update the incomingCallProvider; the MaterialApp builder renders the overlay.
    NotificationService.onIncomingCall = (callData) {
      final callId = callData['callId'] ?? '';
      if (callId.isEmpty) return;
      ref.read(incomingCallProvider.notifier).state = IncomingCallData(
        callId: callId,
        callerName: callData['callerName'] ?? '',
        callerPhone: callData['callerPhone'] ?? '',
        callType: callData['callType'] ?? 'voice',
      );
    };

    // Process pending navigation from widget click
    _checkWidgetNavigation(router);

    return MaterialApp.router(
      title: 'WABEES',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      // FIX: Use builder to add the incoming call overlay on TOP of every screen.
      // This is the WhatsApp-style floating call UI that shows without navigating away.
      builder: (context, child) {
        return Consumer(
          builder: (ctx, ref, _) {
            final incomingCall = ref.watch(incomingCallProvider);
            return Stack(
              children: [
                // The actual app pages
                child ?? const SizedBox.shrink(),

                // Floating incoming call overlay — visible on ANY screen
                if (incomingCall != null)
                  IncomingCallOverlay(
                    data: incomingCall,
                    onAccept: () {
                      // FIX: Resolve actual ownerId from current user
                      // incomingCall.ownerId is always null (FCM doesn't send it)
                      // so we read the logged-in user's dataOwner/id here.
                      final currentUser = ref.read(currentUserProvider);
                      final resolvedOwnerId =
                          currentUser?.dataOwner ?? currentUser?.id;

                      // Dismiss overlay, then navigate to InCallScreen
                      ref.read(incomingCallProvider.notifier).state = null;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        router.pushNamed('in-call', extra: {
                          'callId': incomingCall.callId,
                          'contactName': incomingCall.callerName.isNotEmpty
                              ? incomingCall.callerName
                              : incomingCall.callerPhone,
                          'contactPhone': incomingCall.callerPhone,
                          'isIncoming': true,
                          'ownerId': resolvedOwnerId,
                          'sdpAnswer': null, // incoming — answer generated in InCallScreen
                        });
                      });
                    },
                    onDecline: () => _declineCall(incomingCall),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Check if app was launched from widget click
  void _checkWidgetNavigation(dynamic router) {
    HomeWidget.getWidgetData<String>('widget_navigate_phone').then((phone) {
      if (phone != null && phone.isNotEmpty) {
        HomeWidget.saveWidgetData<String>('widget_navigate_phone', '');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.push('/chat/$phone');
        });
      }
    }).catchError((_) {});
  }
}
