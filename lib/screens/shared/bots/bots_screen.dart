import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/bots/bot_provider.dart';

/// 🤖 BOTS LIST SCREEN
class BotsScreen extends ConsumerWidget {
  const BotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final botsAsync = ref.watch(botsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Reply Bots'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(RouteNames.botBuilder),
            icon: const Icon(Icons.add),
            tooltip: 'Create Bot',
          ),
        ],
      ),
      body: botsAsync.when(
        loading: () => const WbLoading(message: 'Loading bots...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bots) {
          if (bots.isEmpty) {
            return WbEmptyState(
              message: 'No bots yet\nCreate your first auto-reply bot',
              icon: Icons.smart_toy_outlined,
              actionText: 'Create Bot',
              onAction: () => context.pushNamed(RouteNames.botBuilder),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.md),
            itemCount: bots.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (context, index) {
              final bot = bots[index];
              return Dismissible(
                key: Key(bot.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppDimens.md),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                confirmDismiss: (_) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Bot'),
                      content: Text('Delete "${bot.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    return ref.read(botNotifierProvider.notifier).delete(bot.id);
                  }
                  return false;
                },
                child: Card(
                  child: InkWell(
                    onTap: () => context.pushNamed(
                      RouteNames.botBuilder,
                      extra: bot,
                    ),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                color: bot.isActive
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: AppDimens.sm),
                              Expanded(
                                child: Text(
                                  bot.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Active toggle
                              Switch(
                                value: bot.isActive,
                                onChanged: (value) {
                                  ref.read(botNotifierProvider.notifier)
                                      .toggleActive(bot.id, value);
                                },
                              ),
                            ],
                          ),

                          if (bot.description.isNotEmpty) ...[
                            const SizedBox(height: AppDimens.xxs),
                            Text(
                              bot.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: AppDimens.sm),

                          // Trigger info + stats
                          Row(
                            children: [
                              // Trigger type badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                ),
                                child: Text(
                                  bot.triggerType.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimens.sm),
                              // Keywords summary
                              Expanded(
                                child: Text(
                                  bot.triggerSummary,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Stats
                              Icon(
                                Icons.send,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${bot.totalTriggered}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppDimens.sm),

                          // Response preview
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppDimens.sm),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            ),
                            child: Text(
                              bot.responseText.length > 100
                                  ? '${bot.responseText.substring(0, 100)}...'
                                  : bot.responseText,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
}
