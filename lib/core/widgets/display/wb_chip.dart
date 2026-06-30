import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';

/// 🎯 CHIP WIDGET
class WbChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const WbChip({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.sm,
          vertical: AppDimens.xxs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withAlpha(25),
          borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
          border: Border.all(
            color: chipColor.withAlpha(50),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppDimens.iconXs,
                color: isSelected
                    ? Colors.white
                    : (textColor ?? chipColor),
              ),
              const SizedBox(width: AppDimens.xxs),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : (textColor ?? chipColor),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
