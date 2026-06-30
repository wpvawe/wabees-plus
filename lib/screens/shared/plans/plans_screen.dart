import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../providers/plans/plan_provider.dart';
import '../../../providers/auth/auth_provider.dart';

/// 💎 PLANS LIST SCREEN — User views plans & requests upgrade
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final subAsync = ref.watch(subscriptionProvider);
    final actionState = ref.watch(planNotifierProvider);
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isAgent = currentUser?.dataOwner != null && currentUser!.dataOwner!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: plansAsync.when(
        loading: () => const WbLoading(message: 'Loading plans...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const WbEmptyState(
              message: 'No plans available yet',
              icon: Icons.credit_card_off,
            );
          }

          final currentSub = subAsync.valueOrNull;

          return ListView(
            padding: const EdgeInsets.all(AppDimens.md),
            children: [
              // Current subscription info
              if (currentSub != null) ...[
                _CurrentPlanCard(sub: currentSub),
                const SizedBox(height: AppDimens.lg),
              ],

              // Agent Notice
              if (isAgent) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimens.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.withAlpha(20), Colors.orange.withAlpha(8)],
                    ),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: Colors.orange.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are an Agent',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Only the WhatsApp owner can subscribe to plans. '
                              'If you want your own subscription, disconnect from this WhatsApp and connect your own.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.md),
              ],

              // Available plans
              Text(
                'Available Plans',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              ...plans.where((p) => !p.isWelcomePlan).map((plan) {
                final isCurrentPlan = currentSub?.planId == plan.id;
                final isPending = currentSub?.hasPendingUpgrade == true &&
                    currentSub?.pendingPlanId == plan.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.md),
                  child: _PlanCard(
                    plan: plan,
                    isCurrentPlan: isCurrentPlan,
                    isPending: isPending,
                    isLoading: actionState.isLoading,
                    onRequest: isAgent ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Only the WhatsApp owner can subscribe. Disconnect and connect your own WhatsApp for your own plan.'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } : () async {
                      final confirmed = await WbDialog.showConfirm(
                        context,
                        title: 'Request ${plan.name}',
                        message:
                            'Your request will be sent to admin for activation. '
                            'You can chat with admin to complete the payment.',
                      );
                      if (!confirmed) return;

                      final success = await ref
                          .read(planNotifierProvider.notifier)
                          .requestSubscription(plan);

                      if (success && context.mounted) {
                        WbSnackbar.showSuccess(
                          context,
                          'Request sent! Contact admin to activate.',
                        );

                        // Show contact admin dialog
                        _showContactAdminDialog(context, plan.name);
                      }
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showContactAdminDialog(BuildContext context, String planName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Contact Admin'),
          ],
        ),
        content: const Text(
          'To activate your plan, please contact our admin team. '
          'They will guide you through the payment process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushNamed(
                'support-chat',
                extra: 'Hi, I\'d like to activate the "$planName" plan. Please guide me through the payment process.',
              );
            },
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Chat with Admin'),
          ),
        ],
      ),
    );
  }
}

// ============ CURRENT PLAN CARD ============
class _CurrentPlanCard extends StatelessWidget {
  final dynamic sub; // SubscriptionModel

  const _CurrentPlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    String statusText;
    if (sub.isPending) {
      statusColor = Colors.orange;
      statusText = 'Pending Activation';
    } else if (sub.isActive) {
      statusColor = Colors.green;
      statusText = 'Active';
    } else {
      statusColor = Colors.red;
      statusText = 'Expired';
    }

    return Card(
      color: AppColors.primary.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.primary),
                const SizedBox(width: AppDimens.sm),
                Text(
                  'Current: ${sub.planName}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),

            // Usage bars
            _UsageBar(
              label: 'Messages',
              used: sub.messagesUsed,
              max: sub.maxMessages,
            ),
            const SizedBox(height: AppDimens.xs),
            _UsageBar(
              label: 'Contacts',
              used: sub.contactsUsed,
              max: sub.maxContacts,
            ),
            const SizedBox(height: AppDimens.xs),
            _UsageBar(
              label: 'Bots',
              used: sub.botsUsed,
              max: sub.maxBots,
            ),
            const SizedBox(height: AppDimens.xs),
            _UsageBar(
              label: 'Templates',
              used: sub.templatesUsed,
              max: sub.maxTemplates,
            ),
            const SizedBox(height: AppDimens.xs),
            _UsageBar(
              label: 'Campaigns',
              used: sub.campaignsUsed,
              max: sub.maxCampaigns,
            ),
            const SizedBox(height: AppDimens.xs),
            _UsageBar(
              label: 'AI Messages',
              used: sub.aiMessagesUsed,
              max: sub.maxAiMessages,
            ),
            const SizedBox(height: AppDimens.sm),

            // Expiry info
            Text(
              sub.daysRemainingLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (sub.isPending) ...[
              const SizedBox(height: AppDimens.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    context.pushNamed(
                      'support-chat',
                      extra: 'Hi, I have subscribed to the ${sub.planName} plan. Please approve my request.',
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Contact Admin to Activate'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============ PLAN CARD ============
class _PlanCard extends StatelessWidget {
  final dynamic plan; // PlanModel
  final bool isCurrentPlan;
  final bool isPending;
  final bool isLoading;
  final VoidCallback onRequest;

  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.isPending,
    required this.isLoading,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: plan.isPopular ? 4 : 1,
      shape: plan.isPopular
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + popular badge
            Row(
              children: [
                Text(
                  plan.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (plan.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),

            // Price + expiry
            Row(
              children: [
                Text(
                  plan.formattedPrice,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    plan.expiryLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),

            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: AppDimens.xs),
              Text(
                plan.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppDimens.md),
            const Divider(),
            const SizedBox(height: AppDimens.sm),

            // Limits
            _LimitRow(icon: Icons.message, label: '${plan.limitLabel(plan.maxMessages)} messages'),
            _LimitRow(icon: Icons.people, label: '${plan.limitLabel(plan.maxContacts)} contacts'),
            _LimitRow(icon: Icons.smart_toy, label: '${plan.limitLabel(plan.maxBots)} bots'),
            _LimitRow(icon: Icons.description, label: '${plan.limitLabel(plan.maxTemplates)} templates'),
            _LimitRow(icon: Icons.campaign, label: '${plan.limitLabel(plan.maxCampaigns)} campaigns'),
            _LimitRow(icon: Icons.psychology, label: '${plan.limitLabel(plan.maxAiMessages)} AI messages'),

            // Features
            ...plan.features.map(
              (f) => _LimitRow(icon: Icons.check_circle, label: f),
            ),

            const SizedBox(height: AppDimens.lg),

            // Action button
            SizedBox(
              width: double.infinity,
              child: isPending
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('⏳ Pending Activation'),
                    )
                  : isCurrentPlan
                      ? OutlinedButton(
                          onPressed: null,
                          child: const Text('✅ Current Plan'),
                        )
                      : FilledButton(
                          onPressed: isLoading ? null : onRequest,
                          child: const Text('Request Upgrade'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int max;

  const _UsageBar({required this.label, required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final isUnlimited = max == 0;
    final percent = isUnlimited ? 0.0 : (used / max).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: isUnlimited ? 0 : percent,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        Text(
          isUnlimited ? '$used / ∞' : '$used / $max',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _LimitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LimitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
