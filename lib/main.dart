import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:home_widget/home_widget.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

/// Top-level background message handler — MUST be a top-level function
/// (not a class method or closure). Runs in a separate isolate when
/// the app is terminated or in background.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Update home screen widget with the new message in real-time
  try {
    final data = message.data;
    final notification = message.notification;
    final senderName = data['senderName'] ?? notification?.title ?? 'Unknown';
    final body = notification?.body ?? data['body'] ?? '';
    final phone = data['contactPhone'] ?? '';

    if (senderName.isNotEmpty) {
      // Read existing widget data from HomeWidget SharedPreferences
      final existing = await HomeWidget.getWidgetData<String>('widget_conversations') ?? '[]';
      final List<dynamic> items = json.decode(existing) as List<dynamic>;

      // Remove existing entry for this contact to avoid duplicates
      items.removeWhere((item) =>
          item is Map && item['phone'] == phone && phone.isNotEmpty);

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      // Prepend new message at top
      items.insert(0, {
        'name': senderName,
        'message': body.length > 60 ? '${body.substring(0, 60)}...' : body,
        'time': timeStr,
        'phone': phone,
        'unread': 1,
      });

      // Keep only top 5
      final top = items.length > 5 ? items.sublist(0, 5) : items;

      // Save to HomeWidget SharedPreferences (HomeWidgetPreferences)
      await HomeWidget.saveWidgetData<String>('widget_conversations', json.encode(top));
      await HomeWidget.saveWidgetData<String>('widget_update_time', timeStr);

      // Trigger widget refresh
      await HomeWidget.updateWidget(
        name: 'ConversationsWidgetProvider',
        androidName: 'ConversationsWidgetProvider',
        qualifiedAndroidName: 'com.wabees.wabees_android.ConversationsWidgetProvider',
      );
    }
  } catch (_) {
    // Widget update is best-effort
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Initialize Hive for local storage (theme preferences, etc.)
  try {
    await Hive.initFlutter();
  } catch (_) {
    // Hive init can fail on some devices — app still works without it
  }

  // Initialize Notification Service (non-blocking)
  // Done after app start to prevent blocking the UI
  _initNotifications();

  // Enable Firestore offline persistence — CRITICAL for avoiding timeouts
  // on slow networks or first boot. Data is cached locally after first load.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {
    // Settings can only be set once — ignore if already set
  }

  runApp(
    const ProviderScope(
      child: WabeesApp(),
    ),
  );
}

/// Non-blocking notification initialization
Future<void> _initNotifications() async {
  try {
    await NotificationService.instance.initialize();
  } catch (_) {
    // Notifications init can fail — app still works
  }
}
