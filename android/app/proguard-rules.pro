# =============== WABEES PROGUARD RULES ===============

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore
-keep class com.google.cloud.firestore.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Firebase Crashlytics
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Google Play Core (deferred components / split install)
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }

# Hive
-keep class hive.** { *; }
-keep class * extends hive.TypeAdapter { *; }

# Dio
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Flutter Local Notifications — CRITICAL: R8 strips these causing IllegalStateException
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**

# Gson (used by flutter_local_notifications internally)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# General
-keepattributes Signature
-keepattributes Exceptions
-keep class **.R$* { *; }
-dontwarn kotlin.**

# Home Screen Widget — keep widget provider, service, and data classes
-keep class com.wabees.wabees_android.ConversationsWidgetProvider { *; }
-keep class com.wabees.wabees_android.ConversationsWidgetService { *; }
-keep class com.wabees.wabees_android.ConversationsRemoteViewsFactory { *; }
-keep class com.wabees.wabees_android.ConversationItem { *; }
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Flutter Secure Storage — CRITICAL for auth persistence
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# SharedPreferences — auth credential backup
-keep class androidx.datastore.** { *; }
-keep class android.content.SharedPreferences.** { *; }

# flutter_webrtc — WebRTC native bridge
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn com.cloudwebrtc.**

# record — audio recording plugin
-keep class com.llfbandit.record.** { *; }
-dontwarn com.llfbandit.record.**

# just_audio — audio playback plugin
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.**

# image_picker & file_picker — media selection
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**
-dontwarn com.mr.flutter.plugin.filepicker.**

# open_filex — file opener
-keep class com.crazecoder.openfile.** { *; }
-dontwarn com.crazecoder.openfile.**

# cached_network_image / okhttp
-keep class com.squareup.okhttp3.** { *; }
-dontwarn com.squareup.okhttp3.**

# flutter_linkify
-keep class nl.baseflow.linkify.** { *; }

# Kotlin serialization (used by many plugins)
-keepclassmembers class kotlinx.serialization.json.** { *; }
-dontwarn kotlinx.serialization.**

# Suppress known R8 notes
-dontnote **

