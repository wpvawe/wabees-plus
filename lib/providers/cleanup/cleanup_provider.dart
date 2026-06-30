import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cleanup_service.dart';
import '../auth/auth_provider.dart';

// ============ CLEANUP SERVICE ============
final cleanupServiceProvider = Provider<CleanupService>((ref) {
  return CleanupService();
});

// ============ AUTO-CLEANUP ON APP START ============
final autoCleanupProvider = FutureProvider<Map<String, int>?>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;

  final cleanup = ref.watch(cleanupServiceProvider);
  final needed = await cleanup.isCleanupNeeded(userId);

  if (needed) {
    return cleanup.runFullCleanup(userId: userId);
  }
  return null;
});

// ============ CLEANUP STATS ============
final cleanupStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return {};

  final cleanup = ref.watch(cleanupServiceProvider);
  return cleanup.getCleanupStats(userId);
});
