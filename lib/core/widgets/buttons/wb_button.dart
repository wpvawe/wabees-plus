import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// 🎯 MASTER BUTTON WIDGET - 100% REUSABLE
enum WbButtonVariant { primary, secondary, outline, danger, success }
enum WbButtonSize { small, medium, large }

class WbButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final WbButtonVariant variant;
  final WbButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final bool isIconRight;

  const WbButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = WbButtonVariant.primary,
    this.size = WbButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.isIconRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: _getHeight(),
      child: variant == WbButtonVariant.outline
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: _getOutlineStyle(theme),
              child: _buildChild(theme),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: _getElevatedStyle(theme),
              child: _buildChild(theme),
            ),
    );
  }

  double _getHeight() {
    switch (size) {
      case WbButtonSize.small:
        return AppDimens.buttonHeightSm;
      case WbButtonSize.medium:
        return AppDimens.buttonHeightMd;
      case WbButtonSize.large:
        return AppDimens.buttonHeightLg;
    }
  }

  ButtonStyle _getElevatedStyle(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    Color bg;
    Color fg;

    switch (variant) {
      case WbButtonVariant.primary:
        bg = colorScheme.primary;
        fg = colorScheme.onPrimary;
      case WbButtonVariant.secondary:
        bg = colorScheme.secondary;
        fg = colorScheme.onSecondary;
      case WbButtonVariant.danger:
        bg = colorScheme.error;
        fg = colorScheme.onError;
      case WbButtonVariant.success:
        bg = colorScheme.tertiary;
        fg = colorScheme.onTertiary;
      case WbButtonVariant.outline:
        bg = Colors.transparent;
        fg = colorScheme.primary;
    }

    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }

  ButtonStyle _getOutlineStyle(ThemeData theme) {
    return OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      side: BorderSide(color: theme.colorScheme.primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
    );
  }

  Widget _buildChild(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == WbButtonVariant.outline
                ? AppColors.primary
                : Colors.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isIconRight) Icon(icon, size: _getIconSize()),
          if (!isIconRight) const SizedBox(width: AppDimens.xs),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isIconRight) const SizedBox(width: AppDimens.xs),
          if (isIconRight) Icon(icon, size: _getIconSize()),
        ],
      );
    }

    return Text(
      text,
      overflow: TextOverflow.ellipsis,
    );
  }

  double _getIconSize() {
    switch (size) {
      case WbButtonSize.small:
        return AppDimens.iconSm;
      case WbButtonSize.medium:
        return AppDimens.iconMd;
      case WbButtonSize.large:
        return AppDimens.iconLg;
    }
  }
}
