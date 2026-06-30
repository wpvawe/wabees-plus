import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/admin/admin_provider.dart';
import '../../../providers/plans/plan_provider.dart';
import '../../../data/models/plan/subscription_model.dart';

/// 🛡️ ADMIN DASHBOARD — Premium redesigned with clickable cards & quick actions
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _announcementController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _masterPromptController = TextEditingController();

  @override
  void dispose() {
    _announcementController.dispose();
    _minVersionController.dispose();
    _downloadUrlController.dispose();
    _masterPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(liveStatsProvider);
    final pendingSubsAsync = ref.watch(pendingSubscriptionsProvider);
    final pendingAsync = ref.watch(pendingUsersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ============ PREMIUM HERO HEADER ============
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppDimens.md,
                left: AppDimens.md,
                right: AppDimens.md,
                bottom: AppDimens.xl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A0A2E), const Color(0xFF0A1628)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppDimens.radiusXl),
                  bottomRight: Radius.circular(AppDimens.radiusXl),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Panel',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'WABEES Control Center',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.pushNamed('admin-support'),
                        icon: const Icon(Icons.support_agent_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ============ STAT CARDS ============
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.md, AppDimens.md, AppDimens.md, 0),
              child: statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (stats) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.people_alt_rounded,
                            label: 'Total Users',
                            value: '${stats['totalUsers'] ?? 0}',
                            color: const Color(0xFF6366F1),
                            onTap: () => context.pushNamed(RouteNames.adminUsers),
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.verified_rounded,
                            label: 'Active',
                            value: '${stats['activeUsers'] ?? 0}',
                            color: const Color(0xFF10B981),
                            onTap: () => context.pushNamed(RouteNames.adminUsers),
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.pending_rounded,
                            label: 'Pending',
                            value: '${stats['pendingUsers'] ?? 0}',
                            color: const Color(0xFFF59E0B),
                            onTap: () => context.pushNamed(RouteNames.adminUsers),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.block_rounded,
                            label: 'Suspended',
                            value: '${stats['suspendedUsers'] ?? 0}',
                            color: const Color(0xFFEF4444),
                            onTap: () => context.pushNamed(RouteNames.adminUsers),
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.wifi_rounded,
                            label: 'Connected',
                            value: '${stats['connectedUsers'] ?? 0}',
                            color: const Color(0xFF0EA5E9),
                            onTap: () => context.pushNamed(RouteNames.adminUsers),
                          ),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.message_rounded,
                            label: 'Messages',
                            value: '${stats['totalMessages'] ?? 0}',
                            color: const Color(0xFF8B5CF6),
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ============ QUICK ACTIONS ============
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.campaign_rounded,
                        label: 'Announce',
                        color: const Color(0xFFEC4899),
                        onTap: () => _showAnnouncementDialog(context),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      _QuickAction(
                        icon: Icons.system_update_rounded,
                        label: 'App Update',
                        color: const Color(0xFF0EA5E9),
                        onTap: () => _showForceUpdateDialog(context),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      _QuickAction(
                        icon: Icons.diamond_rounded,
                        label: 'Plans',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.pushNamed('admin-plans-manage'),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      _QuickAction(
                        icon: Icons.people_rounded,
                        label: 'Users',
                        color: const Color(0xFF6366F1),
                        onTap: () => context.pushNamed(RouteNames.adminUsers),
                      ),
                      const SizedBox(width: AppDimens.sm),
                      _QuickAction(
                        icon: Icons.chat_rounded,
                        label: 'Support',
                        color: const Color(0xFF10B981),
                        onTap: () => context.pushNamed('admin-support'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.smart_toy_rounded,
                        label: 'AI Bot Master',
                        color: const Color(0xFF10B981),
                        onTap: () => _showMasterPromptDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ============ ACTIVE ANNOUNCEMENT ============
          SliverToBoxAdapter(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('config').doc('announcement').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
                final data = snap.data!.data() as Map<String, dynamic>?;
                if (data == null || data['active'] != true) return const SizedBox.shrink();
                final msg = data['message'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFEC4899).withAlpha(15), const Color(0xFFEC4899).withAlpha(5)],
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(color: const Color(0xFFEC4899).withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFEC4899), size: 24),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active Announcement', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFFEC4899))),
                              Text(msg, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFEC4899), size: 20),
                          onPressed: () => _disableAnnouncement(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.sm)),

          // ============ PENDING SUBSCRIPTIONS ============
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💳 Pending Subscriptions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppDimens.sm),
                  pendingSubsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (subs) {
                      if (subs.isEmpty) {
                        return _EmptyCard(icon: Icons.check_circle_outline, text: 'No pending subscriptions 🎉');
                      }
                      return Column(
                        children: subs.map((data) {
                          final sub = data['subscription'] as SubscriptionModel;
                          final userId = data['userId'] as String;
                          final userName = data['userName'] as String? ?? '';
                          final userEmail = data['userEmail'] as String? ?? '';
                          final userPhone = data['userPhone'] as String? ?? '';
                          final requestedAt = data['requestedAt'] as DateTime?;
                          return _PendingSubCard(
                            sub: sub,
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            userPhone: userPhone,
                            requestedAt: requestedAt,
                            onApprove: () async {
                              final confirm = await WbDialog.showConfirm(context, title: 'Approve Plan', message: 'Activate ${sub.planName} plan for ${userName.isNotEmpty ? userName : "this user"}?');
                              if (confirm) ref.read(planNotifierProvider.notifier).activateSubscription(userId);
                            },
                            onReject: () async {
                              final confirm = await WbDialog.showConfirm(context, title: 'Reject Plan', message: 'Reject ${sub.planName} request from ${userName.isNotEmpty ? userName : "this user"}?', isDanger: true);
                              if (confirm) ref.read(planNotifierProvider.notifier).rejectSubscription(userId);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.md)),

          // ============ PENDING APPROVALS ============
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⏳ Pending Approvals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppDimens.sm),
                  pendingAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (pending) {
                      if (pending.isEmpty) {
                        return _EmptyCard(icon: Icons.check_circle_outline, text: 'No pending approvals 🎉');
                      }
                      return Column(
                        children: pending.take(5).map((user) => Material(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppDimens.xs),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: ListTile(
                              onTap: () => context.pushNamed('admin-user-detail', extra: user),
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.withAlpha(30),
                                child: Text(
                                  user.businessName.isNotEmpty ? user.businessName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(user.businessName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                user.phoneNumber.isNotEmpty ? '${user.email} • ${user.phoneNumber}' : user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () => ref.read(adminNotifierProvider.notifier).approveUser(user.id),
                                child: const Text('Approve'),
                              ),
                            ),
                          ),
                        )).toList(),

                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ============ ANNOUNCEMENT DIALOG ============
  void _showAnnouncementDialog(BuildContext context) {
    _announcementController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Color(0xFFEC4899)),
            SizedBox(width: 8),
            Text('Send Announcement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will be shown to ALL users on their dashboard.'),
            const SizedBox(height: 12),
            TextField(
              controller: _announcementController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter announcement message...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final msg = _announcementController.text.trim();
              if (msg.isEmpty) return;
              await FirebaseFirestore.instance.collection('config').doc('announcement').set({
                'message': msg,
                'active': true,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement sent! ✅')));
              }
            },
            child: const Text('Send to All'),
          ),
        ],
      ),
    );
  }

  void _disableAnnouncement() async {
    await FirebaseFirestore.instance.collection('config').doc('announcement').update({'active': false});
  }

  // ============ FORCE UPDATE DIALOG ============
  void _showForceUpdateDialog(BuildContext context) async {
    // Load current values
    final doc = await FirebaseFirestore.instance.collection('config').doc('app_version').get();
    final data = doc.data() ?? {};
    _minVersionController.text = data['minVersion'] ?? '1.1.3';
    _downloadUrlController.text = data['downloadUrl'] ?? 'https://wabees.live';

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('Force App Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Users with versions lower than this will be forced to update.'),
            const SizedBox(height: 12),
            TextField(
              controller: _minVersionController,
              decoration: const InputDecoration(
                labelText: 'Minimum Version',
                hintText: 'e.g. 1.1.3',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _downloadUrlController,
              decoration: const InputDecoration(
                labelText: 'Download URL',
                hintText: 'https://wabees.live',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('config').doc('app_version').set({
                'minVersion': _minVersionController.text.trim(),
                'downloadUrl': _downloadUrlController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App version config saved ✅')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ============ MASTER PROMPT DIALOG ============
  void _showMasterPromptDialog(BuildContext context) async {
    final doc = await FirebaseFirestore.instance.collection('app_config').doc('ai_bot_master').get();
    final data = doc.data() ?? {};
    _masterPromptController.text = data['masterPrompt'] ?? '';

    if (!mounted) return;
    showDialog(
      context: this.context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Expanded(child: Text('AI Bot Master Prompt')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('These instructions apply to ALL users\' AI bots. Use for global rules and restrictions.'),
            const SizedBox(height: 12),
            TextField(
              controller: _masterPromptController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'e.g. Never discuss competitors...\nAlways recommend visiting office...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('app_config').doc('ai_bot_master').set({
                'masterPrompt': _masterPromptController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Master prompt saved ✅')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ============ PREMIUM STAT CARD ============
class _AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _AdminStatCard({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.sm),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: color.withAlpha(30)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ QUICK ACTION ============
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: color.withAlpha(25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ PENDING SUB CARD ============
class _PendingSubCard extends StatelessWidget {
  final SubscriptionModel sub;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final DateTime? requestedAt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingSubCard({
    required this.sub,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.requestedAt,
    required this.onApprove,
    required this.onReject,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = userName.isNotEmpty ? userName : '...${userId.substring(max(0, userId.length - 6))}';

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: Colors.purple.withAlpha(40),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () => context.pushNamed('admin-user-detail', extra: userId),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: user avatar + name + time
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.purple.withAlpha(30),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (userEmail.isNotEmpty)
                          Text(
                            userEmail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (requestedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDate(requestedAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),

              // Plan details row
              Container(
                padding: const EdgeInsets.all(AppDimens.sm),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(10),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(color: Colors.purple.withAlpha(25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_membership, color: Colors.purple, size: 18),
                    const SizedBox(width: AppDimens.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.planName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.purple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${sub.limitLabel(sub.maxMessages)} msgs • ${sub.limitLabel(sub.maxContacts)} contacts • ${sub.limitLabel(sub.maxAiMessages)} AI msgs • ${sub.expiryType}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (userPhone.isNotEmpty) ...[
                const SizedBox(height: AppDimens.xs),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      userPhone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppDimens.sm),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Activate'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ============ EMPTY CARD ============
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.onSurface.withAlpha(30)),
          const SizedBox(height: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
