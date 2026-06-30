import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../core/router/route_names.dart';
import '../../../data/models/campaign/campaign_status.dart';
import '../../../providers/campaigns/campaign_provider.dart';

/// 📊 CAMPAIGNS LIST SCREEN
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  Future<void> _startCampaign(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Start Campaign',
      message: 'Start sending messages to all recipients?',
    );
    if (!confirmed) return;
    ref.read(campaignNotifierProvider.notifier).executeCampaign(id);
    if (context.mounted) {
      WbSnackbar.showSuccess(context, 'Campaign started! Messages sending...');
    }
  }

  void _pauseCampaign(BuildContext context, WidgetRef ref, String id) {
    ref.read(campaignNotifierProvider.notifier).pause(id);
    WbSnackbar.showSuccess(context, 'Campaign paused');
  }

  void _resumeCampaign(BuildContext context, WidgetRef ref, String id) {
    ref.read(campaignNotifierProvider.notifier).resume(id);
    WbSnackbar.showSuccess(context, 'Campaign resumed!');
  }

  Future<void> _deleteCampaign(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Campaign',
      message: 'Are you sure you want to delete this campaign? This action cannot be undone.',
    );
    if (!confirmed) return;
    final success = await ref.read(campaignNotifierProvider.notifier).delete(id);
    if (context.mounted) {
      if (success) {
        WbSnackbar.showSuccess(context, 'Campaign deleted');
      } else {
        WbSnackbar.showError(context, 'Failed to delete campaign');
      }
    }
  }

  Future<void> _retryCampaign(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Retry Campaign',
      message: 'Retry sending to remaining recipients?',
    );
    if (!confirmed) return;
    ref.read(campaignNotifierProvider.notifier).executeCampaign(id);
    if (context.mounted) {
      WbSnackbar.showSuccess(context, 'Campaign retrying...');
    }
  }


  Future<void> _scheduleCampaign(BuildContext context, WidgetRef ref, String id) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !context.mounted) return;

    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (scheduledAt.isBefore(DateTime.now())) {
      WbSnackbar.showError(context, 'Scheduled time must be in the future');
      return;
    }

    final success = await ref.read(campaignNotifierProvider.notifier).schedule(id, scheduledAt);
    if (context.mounted) {
      if (success) {
        WbSnackbar.showSuccess(context, 'Campaign scheduled for ${scheduledAt.toString().substring(0, 16)}');
      } else {
        WbSnackbar.showError(context, 'Failed to schedule campaign');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);
    final theme = Theme.of(context);

    // Eagerly initialize the scheduler so it auto-starts scheduled campaigns
    ref.watch(campaignSchedulerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(RouteNames.campaignAnalytics),
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Campaign Analytics',
          ),
          IconButton(
            onPressed: () => context.pushNamed(RouteNames.campaignBuilder),
            icon: const Icon(Icons.add),
            tooltip: 'New Campaign',
          ),
        ],
      ),
      body: campaignsAsync.when(
        loading: () => const WbLoading(message: 'Loading campaigns...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return WbEmptyState(
              message: 'No campaigns yet\nCreate your first bulk messaging campaign',
              icon: Icons.campaign_outlined,
              actionText: 'Create Campaign',
              onAction: () => context.pushNamed(RouteNames.campaignBuilder),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.md),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (context, index) {
              final c = campaigns[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  onTap: () => context.pushNamed(
                        RouteNames.campaignDetail,
                        extra: c.id,
                      ),
                  onLongPress: c.status.isEditable
                      ? () => context.pushNamed(
                            RouteNames.campaignBuilder,
                            extra: c,
                          )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Icon(
                              Icons.campaign,
                              color: _statusColor(c.status),
                            ),
                            const SizedBox(width: AppDimens.sm),
                            Expanded(
                              child: Text(
                                c.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _StatusBadge(status: c.status),
                          ],
                        ),

                        if (c.description.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.xxs),
                          Text(
                            c.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: AppDimens.sm),

                        // Analytics row
                        Row(
                          children: [
                            _StatChip(
                              icon: Icons.people,
                              label: '${c.totalRecipients}',
                              tooltip: 'Recipients',
                            ),
                            const SizedBox(width: AppDimens.md),
                            _StatChip(
                              icon: Icons.send,
                              label: '${c.sentCount}',
                              tooltip: 'Sent',
                            ),
                            const SizedBox(width: AppDimens.md),
                            _StatChip(
                              icon: Icons.done_all,
                              label: '${c.deliveredCount}',
                              tooltip: 'Delivered',
                            ),
                            const SizedBox(width: AppDimens.md),
                            _StatChip(
                              icon: Icons.visibility,
                              label: '${c.readCount}',
                              tooltip: 'Read',
                            ),
                            if (c.failedCount > 0) ...[
                              const SizedBox(width: AppDimens.md),
                              _StatChip(
                                icon: Icons.error_outline,
                                label: '${c.failedCount}',
                                tooltip: 'Failed',
                                color: Colors.red,
                              ),
                            ],
                          ],
                        ),

                        // Progress bar for running campaigns
                        if (c.status == CampaignStatus.running) ...[
                          const SizedBox(height: AppDimens.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c.progress / 100,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: AppDimens.xxs),
                          Text(
                            '${c.progress.toStringAsFixed(0)}% complete',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],

                        // Message type indicator
                        const SizedBox(height: AppDimens.sm),
                        Row(
                          children: [
                            Icon(
                              c.isTemplate
                                  ? Icons.description
                                  : Icons.chat_bubble_outline,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              c.isTemplate
                                  ? 'Template: ${c.templateName ?? "N/A"}'
                                  : 'Text message',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        // Action buttons for campaign control
                        const SizedBox(height: AppDimens.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (c.status == CampaignStatus.draft) ...[
                              TextButton.icon(
                                onPressed: () => _scheduleCampaign(context, ref, c.id),
                                icon: const Icon(Icons.schedule, size: 16),
                                label: const Text('Schedule'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                onPressed: () => _startCampaign(context, ref, c.id),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Start'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            if (c.status == CampaignStatus.running)
                              FilledButton.icon(
                                onPressed: () => _pauseCampaign(context, ref, c.id),
                                icon: const Icon(Icons.pause, size: 18),
                                label: const Text('Pause'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                            if (c.status == CampaignStatus.paused)
                              FilledButton.icon(
                                onPressed: () => _resumeCampaign(context, ref, c.id),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Resume'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                            if (c.status == CampaignStatus.failed)
                              FilledButton.icon(
                                onPressed: () => _retryCampaign(context, ref, c.id),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),

                            // Delete button (always visible except running)
                            if (c.status != CampaignStatus.running) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => _deleteCampaign(context, ref, c.id),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: Colors.red.shade400,
                                tooltip: 'Delete',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(32, 32),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(CampaignStatus status) {
    switch (status) {
      case CampaignStatus.draft:
        return Colors.grey;
      case CampaignStatus.scheduled:
        return Colors.blue;
      case CampaignStatus.running:
        return AppColors.primary;
      case CampaignStatus.paused:
        return Colors.orange;
      case CampaignStatus.completed:
        return Colors.green;
      case CampaignStatus.failed:
        return Colors.red;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final CampaignStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case CampaignStatus.draft:
        bg = Colors.grey;
      case CampaignStatus.scheduled:
        bg = Colors.blue;
      case CampaignStatus.running:
        bg = AppColors.primary;
      case CampaignStatus.paused:
        bg = Colors.orange;
      case CampaignStatus.completed:
        bg = Colors.green;
      case CampaignStatus.failed:
        bg = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withAlpha(25),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: bg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color? color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
