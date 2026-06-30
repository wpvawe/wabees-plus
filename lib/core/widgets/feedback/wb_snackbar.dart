import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 MASTER SNACKBAR SYSTEM
class WbSnackbar {
  WbSnackbar._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, const Color(0xFF065F46), Icons.check_circle);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, const Color(0xFFB91C1C), Icons.error);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, const Color(0xFF92400E), Icons.warning);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, const Color(0xFF1E40AF), Icons.info);
  }

  // ── State-based variants (safe to use after await) ──
  static void showSuccessWithState(ScaffoldMessengerState messenger, String message) {
    _showWithState(messenger, message, const Color(0xFF065F46), Icons.check_circle);
  }

  static void showErrorWithState(ScaffoldMessengerState messenger, String message) {
    _showWithState(messenger, message, const Color(0xFFB91C1C), Icons.error);
  }

  static void showInfoWithState(ScaffoldMessengerState messenger, String message) {
    _showWithState(messenger, message, const Color(0xFF1E40AF), Icons.info);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: AppDimens.iconMd),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        margin: AppDimens.screenPadding,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  static void _showWithState(
    ScaffoldMessengerState messenger,
    String message,
    Color color,
    IconData icon,
  ) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: AppDimens.iconMd),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        margin: AppDimens.screenPadding,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
