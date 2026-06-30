import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/campaign/campaign_model.dart';
import '../../../data/models/campaign/campaign_status.dart';
import '../../../providers/campaigns/campaign_provider.dart';

/// 📊 CAMPAIGN DETAIL SCREEN — Real-Time Analytics Dashboard
class CampaignDetailScreen extends ConsumerWidget {
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignDetailProvider(campaignId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign Dashboard'),
      ),
      body: campaignAsync.when(
        loading: () => const WbLoading(message: 'Loading campaign...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (campaign) {
          if (campaign == null) {
            return const Center(child: Text('Campaign not found'));
          }
          return _CampaignDashboard(campaign: campaign);
        },
      ),
    );
  }
}

class _CampaignDashboard extends ConsumerWidget {
  final CampaignModel campaign;
  const _CampaignDashboard({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(campaignLogsProvider(campaign.id));

    return SingleChildScrollView(
      padding: AppDimens.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============ HEADER ============
          _HeaderCard(campaign: campaign),
          const SizedBox(height: AppDimens.md),

          // ============ PROGRESS ============
          _ProgressCard(campaign: campaign),
          const SizedBox(height: AppDimens.md),

          // ============ DONUT CHART ============
          _DonutChartCard(campaign: campaign),
          const SizedBox(height: AppDimens.md),

          // ============ STATS GRID ============
          _StatsGrid(campaign: campaign),
          const SizedBox(height: AppDimens.md),

          // ============ ACTION BUTTONS ============
          _ActionButtons(campaign: campaign),
          const SizedBox(height: AppDimens.md),

          // ============ MESSAGE LOG ============
          Text(
            '📋 Message Log',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimens.sm),
          logsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('Error loading logs: $e'),
            data: (logs) {
              if (logs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No messages sent yet', style: TextStyle(fontSize: 13)),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length > 50 ? 50 : logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isSent = log['status'] == 'sent';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSent ? Icons.check_circle : Icons.error,
                        color: isSent ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        log['phone'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: !isSent && log['reason'] != null
                          ? Text(
                              log['reason'],
                              style: TextStyle(fontSize: 11, color: Colors.red.shade300),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Text(
                        isSent ? '✅' : '❌',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.xl),
        ],
      ),
    );
  }
}

// ============ HEADER CARD ============
class _HeaderCard extends StatelessWidget {
  final CampaignModel campaign;
  const _HeaderCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(status: campaign.status),
              ],
            ),
            if (campaign.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                campaign.description,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  campaign.isTemplate ? Icons.description : Icons.chat,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  campaign.isTemplate
                      ? 'Template: ${campaign.templateName ?? "N/A"}'
                      : 'Text message',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            // Template variable info
            if (campaign.isTemplate && campaign.templateVariables.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.data_object, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${campaign.templateVariables.length} variable(s) · ${campaign.variableSource == 'csv' ? 'Per-recipient (CSV)' : 'Same for all'}',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: campaign.templateVariables.map((v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Text(
                    '{{$v}}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: AppColors.primary,
                    ),
                  ),
                )).toList(),
              ),
            ],
            if (campaign.startedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Started: ${_formatTime(campaign.startedAt!)}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              // Elapsed time + ETA for running campaigns
              if (campaign.status == CampaignStatus.running) ...[
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final elapsed = DateTime.now().difference(campaign.startedAt!);
                  final processed = campaign.sentCount + campaign.failedCount;
                  final remaining = campaign.totalRecipients - processed;
                  String etaText = '';
                  if (processed > 0 && remaining > 0) {
                    final msPerMsg = elapsed.inMilliseconds / processed;
                    final etaMs = (msPerMsg * remaining).round();
                    final eta = Duration(milliseconds: etaMs);
                    etaText = ' · ETA: ${_formatDuration(eta)}';
                  }
                  return Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Elapsed: ${_formatDuration(elapsed)}$etaText',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}

// ============ PROGRESS CARD ============
class _ProgressCard extends StatelessWidget {
  final CampaignModel campaign;
  const _ProgressCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final processed = campaign.sentCount + campaign.failedCount;
    final total = campaign.totalRecipients;
    // Cap at 100% — overcounting protection
    final clampedProcessed = math.min(processed, total);
    final pct = total > 0 ? (clampedProcessed / total * 100).clamp(0.0, 100.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '$clampedProcessed / $total  (${pct.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? (clampedProcessed / total).clamp(0.0, 1.0) : 0,
                minHeight: 10,
                backgroundColor: Colors.grey.withAlpha(40),
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ DONUT CHART CARD ============
class _DonutChartCard extends StatelessWidget {
  final CampaignModel campaign;
  const _DonutChartCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final total = campaign.totalRecipients;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Delivery Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _DonutPainter(
                  sent: campaign.sentCount,
                  delivered: campaign.deliveredCount,
                  read: campaign.readCount,
                  failed: campaign.failedCount,
                  pending: math.max(0, total -
                      campaign.sentCount -
                      campaign.failedCount),
                  totalRecipients: total,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _LegendItem(color: Colors.green, label: 'Sent (${campaign.sentCount})'),
                _LegendItem(color: Colors.blue, label: 'Delivered (${campaign.deliveredCount})'),
                _LegendItem(color: Colors.purple, label: 'Read (${campaign.readCount})'),
                _LegendItem(color: Colors.red, label: 'Failed (${campaign.failedCount})'),
                _LegendItem(
                  color: Colors.grey.shade300,
                  label: 'Pending (${math.max(0, total - campaign.sentCount - campaign.failedCount)})',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ============ DONUT PAINTER ============
class _DonutPainter extends CustomPainter {
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final int pending;
  final int totalRecipients;

  _DonutPainter({
    required this.sent,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.pending,
    required this.totalRecipients,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = sent + failed + (pending > 0 ? pending : 0);
    if (total == 0) {
      // Draw empty circle
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 12,
        paint,
      );
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 24.0;
    double startAngle = -math.pi / 2;

    final segments = <MapEntry<Color, int>>[
      MapEntry(Colors.green, sent - delivered),     // Sent but not delivered
      MapEntry(Colors.blue, delivered - read),      // Delivered but not read
      MapEntry(Colors.purple, read),                // Read
      MapEntry(Colors.red, failed),                  // Failed
      MapEntry(Colors.grey.shade300, pending > 0 ? pending : 0), // Pending
    ];

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.key
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$totalRecipients',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 6,
      ),
    );

    final subPainter = TextPainter(
      text: const TextSpan(
        text: 'total',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(
      canvas,
      Offset(
        center.dx - subPainter.width / 2,
        center.dy + 6,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return sent != oldDelegate.sent ||
        delivered != oldDelegate.delivered ||
        read != oldDelegate.read ||
        failed != oldDelegate.failed ||
        pending != oldDelegate.pending;
  }
}

// ============ STATS GRID ============
class _StatsGrid extends StatelessWidget {
  final CampaignModel campaign;
  const _StatsGrid({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          icon: Icons.send,
          label: 'Sent',
          value: '${campaign.sentCount}',
          pct: campaign.totalRecipients > 0
              ? '${(campaign.sentCount / campaign.totalRecipients * 100).toStringAsFixed(1)}%'
              : '0%',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.done_all,
          label: 'Delivered',
          value: '${campaign.deliveredCount}',
          pct: '${campaign.deliveryRate.toStringAsFixed(1)}%',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.visibility,
          label: 'Read',
          value: '${campaign.readCount}',
          pct: '${campaign.readRate.toStringAsFixed(1)}%',
          color: Colors.purple,
        ),
        _StatCard(
          icon: Icons.error_outline,
          label: 'Failed',
          value: '${campaign.failedCount}',
          pct: campaign.totalRecipients > 0
              ? '${(campaign.failedCount / campaign.totalRecipients * 100).toStringAsFixed(1)}%'
              : '0%',
          color: Colors.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String pct;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                Text('$label · $pct', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ACTION BUTTONS ============
class _ActionButtons extends ConsumerWidget {
  final CampaignModel campaign;
  const _ActionButtons({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(campaignNotifierProvider.notifier);

    if (campaign.status == CampaignStatus.completed ||
        campaign.status == CampaignStatus.failed) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (campaign.status == CampaignStatus.draft)
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final confirmed = await WbDialog.showConfirm(
                  context,
                  title: 'Start Campaign',
                  message: 'Send ${campaign.messageType == "template" ? "template" : "text"} messages to ${campaign.totalRecipients > 0 ? campaign.totalRecipients : campaign.audiencePhones.length} recipients?',
                );
                if (confirmed) {
                  notifier.executeCampaign(campaign.id);
                  if (context.mounted) {
                    WbSnackbar.showSuccess(context, 'Campaign started! Messages sending...');
                  }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Campaign'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        if (campaign.status == CampaignStatus.running)
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                notifier.pause(campaign.id);
                WbSnackbar.showSuccess(context, 'Campaign paused');
              },
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        if (campaign.status == CampaignStatus.paused) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                notifier.resume(campaign.id);
                WbSnackbar.showSuccess(context, 'Campaign resumed!');
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============ STATUS CHIP ============
class _StatusChip extends StatelessWidget {
  final CampaignStatus status;
  const _StatusChip({required this.status});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: bg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
