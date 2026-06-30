import 'package:flutter/material.dart';
import '../../theme/app_dimens.dart';
import '../../utils/helpers/string_helper.dart';

/// 🎯 AVATAR WIDGET
class WbAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;

  const WbAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppDimens.avatarMd,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = StringHelper.initials(name);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? theme.colorScheme.primary.withAlpha(50),
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}
