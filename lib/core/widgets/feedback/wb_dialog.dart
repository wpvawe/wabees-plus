import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 MASTER DIALOG SYSTEM
class WbDialog {
  WbDialog._();

  // ============ ALERT DIALOG ============
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
          content: Text(message, style: TextStyle(color: colors.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(buttonText),
            ),
          ],
        );
      },
    );
  }

  // ============ CONFIRM DIALOG ============
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
          content: Text(message, style: TextStyle(color: colors.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: isDanger
                  ? TextButton.styleFrom(
                      foregroundColor: colors.error,
                    )
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ============ BOTTOM SHEET ============
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: child,
      ),
    );
  }
}
