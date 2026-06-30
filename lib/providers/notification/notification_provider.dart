import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification/app_notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../auth/auth_provider.dart';

// ============ REPOSITORY ============
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// ============ USER NOTIFICATIONS ============
final userNotificationsProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value([]);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUserNotifications(userId);
});

// ============ USER UNREAD COUNT ============
final userNotificationUnreadProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(dataOwnerIdProvider);
  if (userId == null) return Stream.value(0);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUserUnreadCount(userId);
});

// ============ ADMIN NOTIFICATIONS ============
final adminNotificationsProvider = StreamProvider<List<AppNotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getAdminNotifications();
});

// ============ ADMIN UNREAD COUNT ============
final adminNotificationUnreadProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getAdminUnreadCount();
});
