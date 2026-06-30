import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 ICON BUTTON WIDGET
class WbIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;

  const WbIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = AppDimens.iconMd,
    this.color,
    this.backgroundColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: backgroundColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xs),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: size,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
