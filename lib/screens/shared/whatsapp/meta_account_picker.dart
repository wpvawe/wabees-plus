import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/buttons/wb_button.dart';

/// 🔄 REUSABLE META ACCOUNT PICKER
/// Generic bottom sheet picker for businesses, WABAs, phone numbers, etc.
/// Configurable via [MetaEntityConfig] for different entity types.
class MetaAccountPicker extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final List<Map<String, dynamic>> items;
  final MetaEntityConfig config;

  const MetaAccountPicker({
    super.key,
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.items,
    required this.config,
  });

  /// Show as modal bottom sheet — returns selected item or null
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData headerIcon,
    required List<Map<String, dynamic>> items,
    required MetaEntityConfig config,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => MetaAccountPicker(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        items: items,
        config: config,
      ),
    );
  }

  @override
  State<MetaAccountPicker> createState() => _MetaAccountPickerState();
}

class _MetaAccountPickerState extends State<MetaAccountPicker>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(theme),
            _buildHeader(theme),
            const Divider(height: 1),
            _buildList(theme),
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  // ── Handle ──
  Widget _buildHandle(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(30),
                  AppColors.primary.withAlpha(10),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.headerIcon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Item List ──
  Widget _buildList(ThemeData theme) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: widget.items.length,
        itemBuilder: (ctx, index) {
          final item = widget.items[index];
          final isSelected = _selectedIndex == index;
          return _EntityCard(
            item: item,
            config: widget.config,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedIndex = index),
          );
        },
      ),
    );
  }

  // ── Actions ──
  Widget _buildActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withAlpha(60)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: WbButton(
                text: 'Cancel',
                onPressed: () => Navigator.of(context).pop(null),
                variant: WbButtonVariant.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: WbButton(
                text: 'Select',
                onPressed: _selectedIndex != null
                    ? () => Navigator.of(context).pop(widget.items[_selectedIndex!])
                    : null,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ENTITY CONFIG ============
/// Configures how entity items are displayed in the picker.
class MetaEntityConfig {
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>)? subtitleBuilder;
  final String? Function(Map<String, dynamic>)? trailingBuilder;
  final IconData Function(Map<String, dynamic>)? iconBuilder;
  final IconData defaultIcon;

  const MetaEntityConfig({
    required this.titleBuilder,
    this.subtitleBuilder,
    this.trailingBuilder,
    this.iconBuilder,
    this.defaultIcon = Icons.business_rounded,
  });

  // ── Preset: Businesses ──
  static final business = MetaEntityConfig(
    titleBuilder: (item) => item['name']?.toString() ?? 'Unknown Business',
    subtitleBuilder: (item) => 'ID: ${item['id']}',
    defaultIcon: Icons.business_rounded,
  );

  // ── Preset: WABAs ──
  static final waba = MetaEntityConfig(
    titleBuilder: (item) => item['name']?.toString() ?? 'WABA ${item['id']}',
    subtitleBuilder: (item) {
      final currency = item['currency']?.toString() ?? '';
      final status = item['account_review_status']?.toString() ?? '';
      final parts = <String>[];
      if (currency.isNotEmpty) parts.add(currency);
      if (status.isNotEmpty) parts.add(status);
      return parts.isNotEmpty ? parts.join(' · ') : 'ID: ${item['id']}';
    },
    defaultIcon: Icons.chat_rounded,
  );

  // ── Preset: Phone Numbers ──
  static final phone = MetaEntityConfig(
    titleBuilder: (item) =>
        item['display_phone_number']?.toString() ?? 'Unknown Number',
    subtitleBuilder: (item) =>
        item['verified_name']?.toString() ?? 'ID: ${item['id']}',
    trailingBuilder: (item) {
      final quality = item['quality_rating']?.toString() ?? '';
      return quality.isNotEmpty ? quality : null;
    },
    defaultIcon: Icons.phone_android_rounded,
  );
}

// ============ ENTITY CARD ============
class _EntityCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final MetaEntityConfig config;
  final bool isSelected;
  final VoidCallback onTap;

  const _EntityCard({
    required this.item,
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = config.titleBuilder(item);
    final subtitle = config.subtitleBuilder?.call(item);
    final trailing = config.trailingBuilder?.call(item);
    final icon = config.iconBuilder?.call(item) ?? config.defaultIcon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(15)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : theme.dividerColor.withAlpha(40),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [AppColors.primary, AppColors.primary.withAlpha(180)]
                          : [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.primaryContainer.withAlpha(180),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing badge (e.g. quality rating)
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  _QualityBadge(quality: trailing),
                  const SizedBox(width: 8),
                ],

                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.outline.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ QUALITY BADGE ============
class _QualityBadge extends StatelessWidget {
  final String quality;
  const _QualityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (quality.toUpperCase()) {
      case 'GREEN':
        color = Colors.green;
      case 'YELLOW':
        color = Colors.orange;
      case 'RED':
        color = Colors.red;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        quality,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
