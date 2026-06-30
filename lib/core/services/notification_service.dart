import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔔 NOTIFICATION SERVICE — FCM + Local Notifications (with throttling)
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Navigation callback — set from app level
  static void Function(String phone)? onTapNavigate;

  // FIX: Incoming call callback — navigates to InCallScreen when FCM call arrives
  static void Function(Map<String, String> callData)? onIncomingCall;

  // ============ THROTTLE: Prevent bulk notification spam ============
  final Map<String, DateTime> _lastNotificationTime = {};
  static const _throttleDuration = Duration(seconds: 2);
  static const _maxNotificationsPerMinute = 10;
  int _notificationsThisMinute = 0;
  DateTime _minuteStart = DateTime.now();

  // ============ USER PREFERENCES ============
  bool messagesEnabled = true;
  bool campaignsEnabled = true;
  bool botsEnabled = false;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  // ============ LOAD SAVED SETTINGS FROM HIVE ============
  Future<void> _loadSavedSettings() async {
    try {
      final box = await Hive.openBox('notif_settings');
      messagesEnabled  = box.get('messageNotifications',  defaultValue: true)  as bool;
      campaignsEnabled = box.get('campaignNotifications', defaultValue: true)  as bool;
      botsEnabled      = box.get('botNotifications',      defaultValue: false) as bool;
      soundEnabled     = box.get('soundEnabled',          defaultValue: true)  as bool;
      vibrationEnabled = box.get('vibrationEnabled',      defaultValue: true)  as bool;
    } catch (_) {
      // Keep defaults if Hive fails
    }
  }

  // ============ INITIALIZE ============
  Future<void> initialize() async {
    if (_initialized) return;

    // Load persisted notification preferences
    await _loadSavedSettings();

    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    // Local notifications setup
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // Clear corrupted scheduled notifications cache BEFORE init
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('flutter_local_notifications'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}

    // Initialize local notifications
    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
    } catch (_) {
      // If still crashes, continue — FCM still works
    }

    // Create notification channels
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (plugin != null) {
      // Delete old channel with broken sound cache
      try { await plugin.deleteNotificationChannel('wabees_messages'); } catch (_) {}

      // Messages channel
      await plugin.createNotificationChannel(const AndroidNotificationChannel(
        'wabees_messages_v2',
        'Messages',
        description: 'New message notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      // FIX: Dedicated incoming call channel — max priority so it shows over other apps
      await plugin.createNotificationChannel(const AndroidNotificationChannel(
        'wabees_calls',
        'Incoming Calls',
        description: 'Incoming WhatsApp call notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ));
      await plugin.createNotificationChannel(const AndroidNotificationChannel(
        'wabees_campaigns',
        'Campaigns',
        description: 'Campaign status updates',
        importance: Importance.defaultImportance,
      ));
      await plugin.createNotificationChannel(const AndroidNotificationChannel(
        'wabees_system',
        'System',
        description: 'System notifications',
        importance: Importance.low,
      ));
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated message handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened via notification (terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _initialized = true;
  }

  // ============ GET FCM TOKEN ============
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // ============ TOKEN REFRESH STREAM ============
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  // ============ SUBSCRIBE TO TOPIC ============
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  // ============ THROTTLED NOTIFICATION ============
  bool _shouldThrottle(String channelId) {
    // FIX: Never throttle incoming call notifications — they are time-critical
    if (channelId == 'wabees_calls') return false;

    final now = DateTime.now();

    // Reset per-minute counter
    if (now.difference(_minuteStart).inMinutes >= 1) {
      _notificationsThisMinute = 0;
      _minuteStart = now;
    }

    // Max per minute check
    if (_notificationsThisMinute >= _maxNotificationsPerMinute) return true;

    // Per-channel throttle
    final lastTime = _lastNotificationTime[channelId];
    if (lastTime != null && now.difference(lastTime) < _throttleDuration) {
      return true;
    }

    _lastNotificationTime[channelId] = now;
    _notificationsThisMinute++;
    return false;
  }

  // ============ SHOW LOCAL NOTIFICATION ============
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'wabees_messages_v2',
    String channelName = 'Messages',
    int? id,
    String? tag,
  }) async {
    // Throttle check
    if (_shouldThrottle(channelId)) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: '$channelName notifications',
      importance: channelId == 'wabees_calls' ? Importance.max : Importance.high,
      priority: channelId == 'wabees_calls' ? Priority.max : Priority.high,
      showWhen: true,
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
      tag: tag,
      // FIX: Full-screen intent for incoming calls (shows over lock screen)
      fullScreenIntent: channelId == 'wabees_calls',
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ============ CANCEL NOTIFICATION ============
  Future<void> cancel(int id, {String? tag}) async {
    await _localNotifications.cancel(id, tag: tag);
  }

  // ============ HANDLERS ============
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    // FIX: Handle incoming call FCM payload — was completely ignored before!
    if (type == 'incoming_call') {
      _handleIncomingCallFcm(data, fromBackground: false);
      return;
    }

    // Other foreground messages: handled by Firestore stream in notificationListenerProvider
    // to avoid duplicates — no local notification shown here.
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    // FIX: Handle incoming call tap from background notification
    if (type == 'incoming_call') {
      _handleIncomingCallFcm(data, fromBackground: true);
      return;
    }

    final phone = data['contactPhone'] ?? data['from'] ?? '';
    if (phone.isNotEmpty && onTapNavigate != null) {
      onTapNavigate!(phone);
    } else {
      _pendingNavigation = {
        'type': type,
        'phone': phone,
        'payload': phone.isNotEmpty ? 'message:$phone' : type,
      };
    }
  }

  // FIX: Properly handle incoming call FCM notification
  void _handleIncomingCallFcm(Map<String, dynamic> data, {required bool fromBackground}) {
    final callId = data['callId'] ?? '';
    final callerName = data['callerName'] ?? 'Unknown';
    final callerPhone = data['callerPhone'] ?? '';
    final callType = data['callType'] ?? 'voice';

    debugPrint('[FCM] Incoming call: callId=$callId caller=$callerName phone=$callerPhone');

    if (callId.isEmpty) {
      debugPrint('[FCM] Incoming call: missing callId — ignoring');
      return;
    }

    final callData = {
      'callId': callId,
      'callerName': callerName,
      'callerPhone': callerPhone,
      'callType': callType,
    };

    if (fromBackground) {
      // App was in background — store as pending navigation so app can route to InCallScreen
      _pendingNavigation = {
        'type': 'incoming_call',
        'callId': callId,
        'callerName': callerName,
        'callerPhone': callerPhone,
        'callType': callType,
        'payload': 'call:$callId',
      };
    } else {
      // App is in foreground — invoke callback to show InCallScreen immediately
      if (onIncomingCall != null) {
        onIncomingCall!(callData.map((k, v) => MapEntry(k, v.toString())));
      } else {
        // Fallback: store as pending navigation
        _pendingNavigation = {
          'type': 'incoming_call',
          'callId': callId,
          'callerName': callerName,
          'callerPhone': callerPhone,
          'callType': callType,
          'payload': 'call:$callId',
        };
      }
    }

    // Always show a local notification as well (so user sees it on lock screen / notification shade)
    showNotification(
      title: '📞 Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      body: callerName.isNotEmpty ? callerName : callerPhone,
      channelId: 'wabees_calls',
      channelName: 'Incoming Calls',
      id: callId.hashCode,
      tag: 'call_$callId',
      // FIX: Encode full call data so _onNotificationTap can restore callerName/callerPhone
      payload: jsonEncode({
        'type': 'incoming_call',
        'callId': callId,
        'callerName': callerName,
        'callerPhone': callerPhone,
        'callType': callType,
      }),
    );
  }

  Map<String, dynamic>? _pendingNavigation;

  /// Get and clear pending navigation from terminated/background notification
  Map<String, dynamic>? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload ?? '';

    // FIX: Parse JSON-encoded call payload (new format) or legacy 'call:id' format
    if (payload.startsWith('{')) {
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        if (decoded['type'] == 'incoming_call') {
          final callData = {
            'callId': decoded['callId']?.toString() ?? '',
            'callerName': decoded['callerName']?.toString() ?? '',
            'callerPhone': decoded['callerPhone']?.toString() ?? '',
            'callType': decoded['callType']?.toString() ?? 'voice',
          };
          if (onIncomingCall != null) {
            onIncomingCall!(callData);
          } else {
            _pendingNavigation = {'type': 'incoming_call', ...callData, 'payload': payload};
          }
          return;
        }
      } catch (_) {}
    }

    // Legacy format: 'call:callId'
    if (payload.startsWith('call:')) {
      final callId = payload.substring(5);
      if (callId.isNotEmpty) {
        _pendingNavigation = {
          'type': 'incoming_call',
          'callId': callId,
          'payload': payload,
        };
      }
      return;
    }

    if (payload.startsWith('message:')) {
      final phone = payload.substring(8);
      if (phone.isNotEmpty && onTapNavigate != null) {
        onTapNavigate!(phone);
      } else {
        _pendingNavigation = {'type': 'message', 'phone': phone, 'payload': payload};
      }
    } else {
      _pendingNavigation = {'type': payload};
    }
  }

  // ============ CLEAR ALL ============
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
