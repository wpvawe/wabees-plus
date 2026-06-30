import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../data/models/campaign/campaign_status.dart';
import '../../../providers/campaigns/campaign_provider.dart';

/// 📊 CAMPAIGN ANALYTICS OVERVIEW
/// Shows aggregated stats across all campaigns
class CampaignAnalyticsScreen extends ConsumerWidget {
  const CampaignAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign Analytics'),
      ),
      body: campaignsAsync.when(
        loading: () => const WbLoading(message: 'Loading analytics...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return const Center(
              child: Text('No campaigns yet. Create one to see analytics.'),
            );
          }

          // Aggregate stats
          int totalSent = 0;
          int totalDelivered = 0;
          int totalRead = 0;
          int totalFailed = 0;
          int totalRecipients = 0;
          int completedCount = 0;
          int runningCount = 0;
          int draftCount = 0;
          int scheduledCount = 0;
          int failedCount = 0;

          for (final c in campaigns) {
            totalSent += c.sentCount;
            totalDelivered += c.deliveredCount;
            totalRead += c.readCount;
            totalFailed += c.failedCount;
            totalRecipients += c.totalRecipients;
            switch (c.status) {
              case CampaignStatus.completed:
                completedCount++;
              case CampaignStatus.running:
                runningCount++;
              case CampaignStatus.draft:
                draftCount++;
              case CampaignStatus.scheduled:
                scheduledCount++;
              case CampaignStatus.failed:
                failedCount++;
              case CampaignStatus.paused:
                break;
            }
          }

          final deliveryRate = totalSent > 0
              ? (totalDelivered / totalSent * 100).toStringAsFixed(1)
              : '0.0';
          final readRate = totalDelivered > 0
              ? (totalRead / totalDelivered * 100).toStringAsFixed(1)
              : '0.0';
          final failRate = totalSent > 0
              ? (totalFailed / (totalSent + totalFailed) * 100).toStringAsFixed(1)
              : '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============ SUMMARY CARDS ============
                Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),

                // Campaign status summary row
                Row(
                  children: [
                    _SummaryCard(
                      icon: Icons.campaign,
                      label: 'Total',
                      value: '${campaigns.length}',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    _SummaryCard(
                      icon: Icons.check_circle,
                      label: 'Completed',
                      value: '$completedCount',
                      color: Colors.green,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    _SummaryCard(
                      icon: Icons.play_circle,
                      label: 'Running',
                      value: '$runningCount',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    _SummaryCard(
                      icon: Icons.schedule,
                      label: 'Scheduled',
                      value: '$scheduledCount',
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    _SummaryCard(
                      icon: Icons.edit_note,
                      label: 'Drafts',
                      value: '$draftCount',
                      color: Colors.grey,
                    ),
                    const SizedBox(width: AppDimens.sm),
                    _SummaryCard(
                      icon: Icons.error_outline,
                      label: 'Failed',
                      value: '$failedCount',
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: AppDimens.lg),

                // ============ MESSAGING STATS ============
                Text(
                  'Messaging',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),

                // Main messaging stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BigStat(
                                label: 'Total Recipients',
                                value: '$totalRecipients',
                                icon: Icons.people,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Expanded(
                              child: _BigStat(
                                label: 'Messages Sent',
                                value: '$totalSent',
                                icon: Icons.send,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _BigStat(
                                label: 'Delivered',
                                value: '$totalDelivered',
                                icon: Icons.done_all,
                                color: Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _BigStat(
                                label: 'Read',
                                value: '$totalRead',
                                icon: Icons.visibility,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _BigStat(
                                label: 'Failed',
                                value: '$totalFailed',
                                icon: Icons.error_outline,
                                color: Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _BigStat(
                                label: 'Drafts',
                                value: '$draftCount',
                                icon: Icons.edit_note,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimens.lg),

                // ============ RATES ============
                Text(
                  'Performance Rates',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      children: [
                        _RateRow(
                          label: 'Delivery Rate',
                          rate: '$deliveryRate%',
                          progress: totalSent > 0
                              ? totalDelivered / totalSent
                              : 0,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _RateRow(
                          label: 'Read Rate',
                          rate: '$readRate%',
                          progress: totalDelivered > 0
                              ? totalRead / totalDelivered
                              : 0,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _RateRow(
                          label: 'Failure Rate',
                          rate: '$failRate%',
                          progress: totalSent > 0
                              ? totalFailed / (totalSent + totalFailed)
                              : 0,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimens.lg),

                // ============ PER-CAMPAIGN BREAKDOWN ============
                Text(
                  'Campaign Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.sm),

                ...campaigns.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: AppDimens.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.campaign,
                              size: 18,
                              color: _statusColor(c.status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(c.status).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statusColor(c.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        if (c.totalRecipients > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c.sentCount / c.totalRecipients,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              color: _statusColor(c.status),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(label: 'Sent', value: '${c.sentCount}', color: AppColors.primary),
                            _MiniStat(label: 'Delivered', value: '${c.deliveredCount}', color: Colors.green),
                            _MiniStat(label: 'Read', value: '${c.readCount}', color: Colors.blue),
                            _MiniStat(label: 'Failed', value: '${c.failedCount}', color: Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),

                const SizedBox(height: AppDimens.xl),
              ],
            ),
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

// ============ WIDGETS ============

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BigStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final String rate;
  final double progress;
  final Color color;

  const _RateRow({
    required this.label,
    required this.rate,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(rate, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
