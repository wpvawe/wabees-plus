import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/template/template_model.dart';
import '../../../providers/templates/template_provider.dart';
import 'template_builder_screen.dart';
import 'template_send_dialog.dart';

/// 📋 TEMPLATES LIBRARY — Browse, Search, Filter, Apply
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    // Auto-sync on first load
    Future.microtask(() async {
      final notifier = ref.read(templateNotifierProvider.notifier);
      await notifier.syncFromMeta();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templatesAsync = ref.watch(filteredTemplatesProvider);
    final actionState = ref.watch(templateNotifierProvider);
    final stats = ref.watch(templateStatsProvider);
    final selectedCategory = ref.watch(templateCategoryFilterProvider);
    final selectedStatus = ref.watch(templateStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? _SearchField(
                controller: _searchController,
                onChanged: (v) =>
                    ref.read(templateSearchQueryProvider.notifier).state = v,
                onClose: () {
                  setState(() => _showSearch = false);
                  _searchController.clear();
                  ref.read(templateSearchQueryProvider.notifier).state = '';
                },
              )
            : const Text('Templates Library'),
        actions: [
          if (!_showSearch)
            IconButton(
              onPressed: () => setState(() => _showSearch = true),
              icon: const Icon(Icons.search),
              tooltip: 'Search templates',
            ),
          IconButton(
            onPressed: actionState.isLoading ? null : _syncTemplates,
            icon: actionState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync from WhatsApp',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TemplateBuilderScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ============ STATS ROW ============
          _StatsRow(stats: stats),

          // ============ CATEGORY FILTER ============
          _CategoryFilter(
            selected: selectedCategory,
            onChanged: (v) =>
                ref.read(templateCategoryFilterProvider.notifier).state = v,
          ),

          // ============ STATUS FILTER ============
          _StatusFilter(
            selected: selectedStatus,
            onChanged: (v) =>
                ref.read(templateStatusFilterProvider.notifier).state = v,
          ),

          // ============ TEMPLATE LIST ============
          Expanded(
            child: templatesAsync.when(
              data: (templates) {
                if (templates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined,
                            size: 56,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(80)),
                        const SizedBox(height: AppDimens.md),
                        Text(
                          'No templates found',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppDimens.xs),
                        Text(
                          'Create one or sync from WhatsApp',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: AppDimens.xs,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (_, i) => _TemplateCard(
                    template: templates[i],
                    onSend: () => _sendTemplate(templates[i]),
                    onEdit: () => _editTemplate(templates[i]),
                    onDelete: () => _deleteTemplate(templates[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncTemplates() async {
    final count =
        await ref.read(templateNotifierProvider.notifier).syncFromMeta();
    if (mounted) {
      WbSnackbar.showSuccess(context, '$count templates synced');
    }
  }

  void _sendTemplate(TemplateModel template) {
    if (!template.canSend) {
      WbSnackbar.showWarning(
          context, 'Template must be approved before sending');
      return;
    }
    TemplateSendDialog.show(context, template);
  }

  void _editTemplate(TemplateModel template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplateBuilderScreen(existingTemplate: template),
      ),
    );
  }

  Future<void> _deleteTemplate(TemplateModel template) async {
    final message = template.isSynced
        ? 'This will delete "${template.name}" from WhatsApp Business AND this app. Cannot be undone.'
        : 'Delete "${template.name}" from this app?';

    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Template',
      message: message,
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      final success =
          await ref.read(templateNotifierProvider.notifier).delete(template);
      if (mounted) {
        if (success) {
          WbSnackbar.showSuccess(context, 'Template deleted');
        } else {
          final error = ref.read(templateNotifierProvider).error;
          WbSnackbar.showError(context, error ?? 'Failed to delete');
        }
      }
    }
  }
}

// ============ SEARCH FIELD ============
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search templates...',
        border: InputBorder.none,
        suffixIcon: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

// ============ STATS ROW ============
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(30),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MiniStat(
            label: 'Total',
            value: stats['total'] ?? 0,
            color: AppColors.primary,
          ),
          _MiniStat(
            label: 'Approved',
            value: stats['approved'] ?? 0,
            color: AppColors.success,
          ),
          _MiniStat(
            label: 'Pending',
            value: stats['pending'] ?? 0,
            color: AppColors.warning,
          ),
          _MiniStat(
            label: 'Rejected',
            value: stats['rejected'] ?? 0,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ============ CATEGORY FILTER ============
class _CategoryFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryFilter({required this.selected, required this.onChanged});

  static const _categories = [
    {'value': 'ALL', 'label': 'All', 'icon': Icons.dashboard},
    {'value': 'MARKETING', 'label': 'Marketing', 'icon': Icons.campaign},
    {'value': 'UTILITY', 'label': 'Utility', 'icon': Icons.build},
    {'value': 'AUTHENTICATION', 'label': 'Auth', 'icon': Icons.lock},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.xs),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isActive = selected == cat['value'];
          return _FilterChip(
            label: cat['label'] as String,
            icon: cat['icon'] as IconData,
            isActive: isActive,
            onTap: () => onChanged(cat['value'] as String),
          );
        },
      ),
    );
  }
}

// ============ STATUS FILTER ============
class _StatusFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusFilter({required this.selected, required this.onChanged});

  static const _statuses = [
    {'value': 'ALL', 'label': 'All Status', 'color': 0xFF6366F1},
    {'value': 'APPROVED', 'label': 'Approved', 'color': 0xFF10B981},
    {'value': 'PENDING', 'label': 'Pending', 'color': 0xFFF59E0B},
    {'value': 'REJECTED', 'label': 'Rejected', 'color': 0xFFEF4444},
    {'value': 'PAUSED', 'label': 'Paused', 'color': 0xFF8B5CF6},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.xs),
        itemBuilder: (_, i) {
          final s = _statuses[i];
          final isActive = selected == s['value'];
          final color = Color(s['color'] as int);
          return GestureDetector(
            onTap: () => onChanged(s['value'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? color.withAlpha(20) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                border: Border.all(
                  color: isActive ? color : color.withAlpha(60),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  s['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? color : color.withAlpha(180),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============ FILTER CHIP ============
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(20)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : theme.colorScheme.outline.withAlpha(50),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color:
                  isActive ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ TEMPLATE CARD ============
class _TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onSend,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (template.status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.success;
      case 'PENDING':
        return AppColors.warning;
      case 'REJECTED':
        return AppColors.error;
      case 'PAUSED':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.info;
    }
  }

  IconData get _categoryIcon {
    switch (template.category.toUpperCase()) {
      case 'MARKETING':
        return Icons.campaign;
      case 'UTILITY':
        return Icons.build;
      case 'AUTHENTICATION':
        return Icons.lock;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.md,
              AppDimens.sm,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _statusColor.withAlpha(15),
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Icon(_categoryIcon, size: 18, color: _statusColor),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            template.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            template.languageCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (template.canSend)
                  IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send, size: 20),
                    color: AppColors.primary,
                    tooltip: 'Send',
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18,
                              color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body preview
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.xs,
              AppDimens.md,
              AppDimens.xs,
            ),
            child: Text(
              template.body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Footer info
          if (template.variables.isNotEmpty || template.qualityScore != null)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                AppDimens.xs,
                AppDimens.md,
                AppDimens.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(20),
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (template.variables.isNotEmpty) ...[
                    Icon(Icons.data_object,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${template.variables.length} vars',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (template.qualityScore != null) ...[
                    Icon(
                      _qualityIcon(template.qualityScore!),
                      size: 14,
                      color: _qualityColor(template.qualityScore!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      template.qualityScore!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _qualityColor(template.qualityScore!),
                      ),
                    ),
                  ],
                  if (template.isSynced) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.cloud_done,
                        size: 14, color: AppColors.success.withAlpha(180)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _qualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case 'GREEN':
        return AppColors.success;
      case 'YELLOW':
        return AppColors.warning;
      case 'RED':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _qualityIcon(String quality) {
    switch (quality.toUpperCase()) {
      case 'GREEN':
        return Icons.check_circle;
      case 'YELLOW':
        return Icons.warning;
      case 'RED':
        return Icons.error;
      default:
        return Icons.info;
    }
  }
}
