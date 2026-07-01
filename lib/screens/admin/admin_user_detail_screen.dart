import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/models/support/support_chat_model.dart';
import '../../../providers/admin/admin_provider.dart';
import '../../../providers/plans/plan_provider.dart';
import 'admin_support_screen.dart';

/// 🛡️ ADMIN USER DETAIL SCREEN — View user details and manage
class AdminUserDetailScreen extends ConsumerWidget {
  final UserModel user;

  const AdminUserDetailScreen({super.key, required this.user});

  /// Named constructor: navigate from userId only (fetches user from Firestore)
  static Widget fromId({required String userId}) {
    return _AdminUserDetailFromId(userId: userId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.businessName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, action, ref),
            itemBuilder: (ctx) => [
              if (user.status.isPending)
                const PopupMenuItem(
                  value: 'approve',
                  child: Text('✅ Approve'),
                ),
              if (user.status.isActive)
                const PopupMenuItem(
                  value: 'suspend',
                  child: Text('⏸️ Suspend'),
                ),
              if (user.status.isSuspended) ...[
                const PopupMenuItem(
                  value: 'reactivate',
                  child: Text('▶️ Reactivate'),
                ),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Text('🚫 Deactivate'),
                ),
              ],
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.md),
        children: [
          // ============ USER INFO CARD ============
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withAlpha(30),
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? const Icon(Icons.person,
                            size: 40, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(height: AppDimens.md),
                  Text(
                    user.businessName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoChip(
                        label: user.status.label,
                        color: _statusColor(user.status),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      _InfoChip(
                        label: user.role.label,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.md),

          // ============ USAGE STATS ============
          Text(
            '📊 Usage Statistics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppDimens.sm,
            crossAxisSpacing: AppDimens.sm,
            childAspectRatio: 1.6, // Extra height to prevent overflow on small screens
            children: [
              _StatTile(
                icon: Icons.message,
                label: 'Messages',
                value: '${user.totalMessages}',
              ),
              _StatTile(
                icon: Icons.contacts,
                label: 'Contacts',
                value: '${user.totalContacts}',
              ),
              _StatTile(
                icon: Icons.smart_toy,
                label: 'Bots',
                value: '${user.totalBots}',
              ),
              _StatTile(
                icon: Icons.campaign,
                label: 'Campaigns',
                value: '${user.totalCampaigns}',
              ),
            ],
          ),

          const SizedBox(height: AppDimens.md),

          // ============ WHATSAPP STATUS ============
          Text(
            '📱 WhatsApp Connection',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Card(
            child: ListTile(
              leading: Icon(
                user.whatsappConnected
                    ? Icons.check_circle
                    : Icons.cancel,
                color: user.whatsappConnected ? Colors.green : Colors.red,
              ),
              title: Text(
                user.whatsappConnected ? 'Connected' : 'Not Connected',
              ),
              subtitle: user.whatsappPhoneNumberId != null
                  ? Text('Phone ID: ${user.whatsappPhoneNumberId}')
                  : const Text('No WhatsApp configured'),
            ),
          ),

          const SizedBox(height: AppDimens.md),

          // ============ ACCOUNT INFO ============
          Text(
            '📋 Account Info',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.calendar_today, size: 18),
                  title: const Text('Created'),
                  trailing: Text(
                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (user.updatedAt != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.update, size: 18),
                    title: const Text('Last Updated'),
                    trailing: Text(
                      '${user.updatedAt!.day}/${user.updatedAt!.month}/${user.updatedAt!.year}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.fingerprint, size: 18),
                  title: const Text('User ID'),
                  trailing: Text(
                    user.id.substring(0, user.id.length > 12 ? 12 : user.id.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.md),

          // ============ AI BOT FEATURE TOGGLE ============
          Text(
            '🤖 AI Bot Feature',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.id).snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final aiBotOn = data?['aiBotEnabled'] ?? false;
              return Card(
                child: SwitchListTile(
                  secondary: Icon(
                    aiBotOn ? Icons.smart_toy : Icons.smart_toy_outlined,
                    color: aiBotOn ? Colors.green : Colors.grey,
                  ),
                  title: Text(aiBotOn ? 'AI Bot Enabled' : 'AI Bot Disabled'),
                  subtitle: Text(
                    aiBotOn
                        ? 'User can configure and use AI auto-reply bot'
                        : 'Enable to allow this user to use AI bot feature',
                  ),
                  value: aiBotOn,
                  activeThumbColor: Colors.green,
                  onChanged: (val) async {
                    await ref.read(adminNotifierProvider.notifier).updateUserField(
                          user.id,
                          'aiBotEnabled',
                          val,
                        );
                    if (context.mounted) {
                      WbSnackbar.showSuccess(
                        context,
                        val ? 'AI Bot enabled for ${user.businessName}' : 'AI Bot disabled',
                      );
                    }
                  },
                ),
              );
            },
          ),

          const SizedBox(height: AppDimens.md),

          // ============ SUBSCRIPTION MANAGEMENT ============
          Text(
            '💎 Subscription',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Consumer(
            builder: (context, ref, _) {
              final subStream = ref.watch(
                adminUserSubscriptionProvider(user.id),
              );

              return subStream.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimens.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Card(
                  child: ListTile(
                    leading: Icon(Icons.error, color: Colors.red),
                    title: Text('Error loading subscription'),
                  ),
                ),
                data: (sub) {
                  if (sub == null) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.credit_card_off, color: Colors.grey),
                        title: Text('No subscription'),
                      ),
                    );
                  }

                  Color statusColor;
                  if (sub.isPending) {
                    statusColor = Colors.orange;
                  } else if (sub.isActive) {
                    statusColor = Colors.green;
                  } else {
                    statusColor = Colors.red;
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.credit_card, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(sub.planName, style: theme.textTheme.titleSmall),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sub.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Messages: ${sub.messagesUsed}/${sub.maxMessages == 0 ? "∞" : sub.maxMessages}'),
                          Text('Contacts: ${sub.contactsUsed}/${sub.maxContacts == 0 ? "∞" : sub.maxContacts}'),
                          Text('AI Messages: ${sub.aiMessagesUsed}/${sub.maxAiMessages == 0 ? "∞" : sub.maxAiMessages}'),
                          if (sub.isPending) ...[
                            const SizedBox(height: AppDimens.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      final ok = await ref
                                          .read(planNotifierProvider.notifier)
                                          .activateSubscription(user.id);
                                      if (ok && context.mounted) {
                                        WbSnackbar.showSuccess(context, 'Subscription activated');
                                      }
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Activate'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final confirmed = await WbDialog.showConfirm(
                                        context,
                                        title: 'Reject Subscription',
                                        message: 'Reject and revert to Welcome plan?',
                                        isDanger: true,
                                      );
                                      if (!confirmed) return;
                                      final ok = await ref
                                          .read(planNotifierProvider.notifier)
                                          .rejectSubscription(user.id);
                                      if (ok && context.mounted) {
                                        WbSnackbar.showSuccess(context, 'Subscription rejected');
                                      }
                                    },
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: AppDimens.sm),

          // Chat with user button
          FilledButton.icon(
            onPressed: () {
              final chat = SupportChatModel(
                id: user.id,
                userId: user.id,
                userName: user.businessName,
                userEmail: user.email,
                createdAt: DateTime.now(),
              );
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminChatDetail(chat: chat),
              ));
            },
            icon: const Icon(Icons.chat),
            label: Text('Chat with ${user.businessName}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    WidgetRef ref,
  ) async {
    final notifier = ref.read(adminNotifierProvider.notifier);
    bool success = false;

    switch (action) {
      case 'approve':
        success = await notifier.approveUser(user.id);
        if (success && context.mounted) {
          WbSnackbar.showSuccess(context, 'User approved');
        }
        break;
      case 'suspend':
        final confirmed = await WbDialog.showConfirm(
          context,
          title: 'Suspend User',
          message: 'Suspend ${user.businessName}?',
          isDanger: true,
        );
        if (!confirmed) return;
        success = await notifier.suspendUser(user.id);
        if (success && context.mounted) {
          WbSnackbar.showSuccess(context, 'User suspended');
        }
        break;
      case 'reactivate':
        success = await notifier.reactivateUser(user.id);
        if (success && context.mounted) {
          WbSnackbar.showSuccess(context, 'User reactivated');
        }
        break;
      case 'deactivate':
        final confirmed = await WbDialog.showConfirm(
          context,
          title: 'Deactivate User',
          message: 'Permanently deactivate ${user.businessName}?',
          isDanger: true,
        );
        if (!confirmed) return;
        success = await notifier.deactivateUser(user.id);
        if (success && context.mounted) {
          WbSnackbar.showSuccess(context, 'User deactivated');
        }
        break;
    }
  }

  Color _statusColor(status) {
    if (status.isActive) return Colors.green;
    if (status.isPending) return Colors.orange;
    if (status.isSuspended) return Colors.red;
    return Colors.grey;
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Fetches user by ID then shows AdminUserDetailScreen
class _AdminUserDetailFromId extends ConsumerWidget {
  final String userId;
  const _AdminUserDetailFromId({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<UserModel?>(
      future: ref.read(adminRepositoryProvider).getUser(userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Not Found')),
            body: const Center(
              child: Text('Could not load user details.'),
            ),
          );
        }
        return AdminUserDetailScreen(user: user);
      },
    );
  }
}
