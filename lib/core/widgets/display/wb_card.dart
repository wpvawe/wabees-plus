import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 CARD WIDGET
class WbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;

  const WbCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color ?? theme.colorScheme.surface,
      elevation: elevation ?? 0,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: padding ?? AppDimens.cardPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(25),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
