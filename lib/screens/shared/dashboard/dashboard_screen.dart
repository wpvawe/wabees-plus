import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/display/wb_avatar.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/messaging/messaging_provider.dart';
import '../../../providers/admin/admin_provider.dart';
import '../../../providers/notification/notification_provider.dart';
import '../../../providers/notification/notification_listener_provider.dart';
import '../../../providers/plans/plan_provider.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';
import '../../../providers/bots/bot_provider.dart';
import '../../../providers/templates/template_provider.dart';
import '../../../providers/campaigns/campaign_provider.dart';
import '../../../data/models/plan/subscription_model.dart';
import '../../../data/models/message/conversation_model.dart';
import '../../../providers/contacts/contact_provider.dart';

/// ðŸŽ¯ DASHBOARD SCREEN - PREMIUM REDESIGN
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<bool> _onWillPop(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you really want to exit WABEES?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: WbLoading());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: isAdmin ? _AdminDashboard(user: user) : _UserDashboard(user: user),
      ),
    );
  }
}

// ================================================================
// ==================== USER DASHBOARD ==========================
// ================================================================
class _UserDashboard extends ConsumerWidget {
  final dynamic user;
  const _UserDashboard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final conversationsAsync = ref.watch(conversationsProvider);
    // For agents, read stats from owner's user doc
    final ownerUser = ref.watch(dataOwnerUserProvider).valueOrNull ?? user;
    // Repair totalBots mismatch by comparing with live bots list
    // Repair totalBots mismatch â€” write to owner's doc
    ref.listen(botsProvider, (prev, next) {
      next.whenData((bots) {
        final u = ref.read(currentUserProvider);
        if (u != null) {
          final ownerId = u.dataOwner ?? u.id;
          ref.read(userRepositoryProvider).updateUser(ownerId, {'totalBots': bots.length});
        }
      });
    });

    // Activate notification listener for incoming messages
    ref.watch(notificationListenerProvider);

    // Sync AI message limits from plan on app start (fixes existing users)
    ref.listen(subscriptionProvider, (prev, next) {
      next.whenData((sub) {
        if (sub != null && prev?.valueOrNull == null) {
          final ownerId = user.dataOwner ?? user.id;
          ref.read(planRepositoryProvider).syncSubscriptionLimits(ownerId);
        }
      });
    });

    return CustomScrollView(
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
                    ? [const Color(0xFF0D2818), const Color(0xFF0A1628)]
                    : [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimens.radiusXl),
                bottomRight: Radius.circular(AppDimens.radiusXl),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppColors.primary).withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: WbAvatar(name: user.businessName, size: AppDimens.avatarLg),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            user.businessName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Support button
                    IconButton(
                      onPressed: () => context.pushNamed(RouteNames.support),
                      icon: const Icon(Icons.support_agent_rounded, color: Colors.white70),
                      tooltip: 'Support',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    _NotificationBadge(isAdmin: false),
                  ],
                ),

                const SizedBox(height: AppDimens.md),

                // WhatsApp Status Badge (Improved)
                _WhatsAppStatusBadge(connected: user.whatsappConnected),
              ],
            ),
          ),
        ),

        // ============ MESSAGE USAGE / PLAN CARD ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.md, AppDimens.md, AppDimens.md, 0),
            child: ref.watch(subscriptionProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (sub) {
                if (sub == null) return const SizedBox.shrink();
                final isUnlimited = sub.maxMessages == 0;
                final used = sub.messagesUsed;
                final max = sub.maxMessages;
                final remaining = sub.messagesRemaining;
                final percent = isUnlimited || max <= 0
                    ? 0.0
                    : (used / max).clamp(0.0, 1.0);

                return _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Message Usage',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (sub.isLifetime)
                            const _Chip(label: 'Lifetime', color: Color(0xFF16A34A))
                          else
                            _Chip(
                              label: sub.daysRemainingLabel,
                              color: const Color(0xFF2563EB),
                            ),
                          if (sub.hasPendingUpgrade) ...[
                            const SizedBox(width: 6),
                            _Chip(
                              label: '\u23f3 ${sub.pendingPlanName} pending',
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: LinearProgressIndicator(
                          value: isUnlimited ? 0 : percent,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percent > 0.9
                                ? Colors.redAccent
                                : percent > 0.7
                                    ? Colors.orangeAccent
                                    : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isUnlimited
                                  ? '${sub.planName} • Unlimited messages'
                                  : '${sub.planName} • $used / $max messages used',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isUnlimited)
                            Text(
                              remaining <= 0 ? '0 left' : '$remaining left',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: percent > 0.9
                                        ? Colors.redAccent
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.md)),

        // ============ ANNOUNCEMENT BANNER ============
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('config').doc('announcement').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
              final data = snap.data!.data() as Map<String, dynamic>?;
              if (data == null || data['active'] != true) return const SizedBox.shrink();
              final msg = data['message'] ?? '';
              return Padding(
                padding: const EdgeInsets.fromLTRB(AppDimens.md, 0, AppDimens.md, AppDimens.md),
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
                      const Icon(Icons.campaign_rounded, color: Color(0xFFEC4899), size: 22),
                      const SizedBox(width: AppDimens.sm),
                      Expanded(
                        child: Text(
                          msg,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFEC4899),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ============ STAT CARDS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Column(
              children: [
                Row(
                  children: [
                    // Row 1: Messages, Contacts, Bots
                    Expanded(
                      child: conversationsAsync.when(
                        loading: () => _StatCard(
                          title: 'Messages',
                          value: '${ownerUser.totalMessages}',
                          icon: Icons.message_rounded,
                          color: const Color(0xFF6366F1),
                          onTap: () => context.goNamed(RouteNames.messages),
                        ),
                        error: (_, __) => _StatCard(
                          title: 'Messages',
                          value: '${ownerUser.totalMessages}',
                          icon: Icons.message_rounded,
                          color: const Color(0xFF6366F1),
                          onTap: () => context.goNamed(RouteNames.messages),
                        ),
                        data: (conversations) {
                          final totalUnread = conversations.fold<int>(
                            0, (acc, c) => acc + c.unreadCount,
                          );
                          return _StatCard(
                            title: 'Messages',
                            value: '${ownerUser.totalMessages}',
                            icon: Icons.message_rounded,
                            color: const Color(0xFF6366F1),
                            badge: totalUnread > 0 ? '$totalUnread' : null,
                            onTap: () => context.goNamed(RouteNames.messages),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(ownerUser.id)
                            .collection('contacts')
                            .snapshots()
                            .map((s) => s.docs.length),
                        builder: (context, snap) => _StatCard(
                          title: 'Contacts',
                          value: snap.hasData ? '${snap.data}' : '${ownerUser.totalContacts}',
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFF0EA5E9),
                          onTap: () => context.goNamed(RouteNames.contacts),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _StatCard(
                        title: 'Bots',
                        value: '${ownerUser.totalBots}',
                        icon: Icons.smart_toy_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () => context.pushNamed(RouteNames.bots),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                // Row 2: Campaigns, Templates (wider cards)
                Row(
                  children: [
                    Expanded(
                      child: ref.watch(campaignsProvider).when(
                        loading: () => _StatCard(
                          title: 'Campaigns',
                          value: '...',
                          icon: Icons.campaign_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.pushNamed(RouteNames.campaigns),
                        ),
                        error: (_, __) => _StatCard(
                          title: 'Campaigns',
                          value: '0',
                          icon: Icons.campaign_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.pushNamed(RouteNames.campaigns),
                        ),
                        data: (campaigns) => _StatCard(
                          title: 'Campaigns',
                          value: '${campaigns.length}',
                          icon: Icons.campaign_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.pushNamed(RouteNames.campaigns),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: ref.watch(templatesProvider).when(
                        loading: () => _StatCard(
                          title: 'Templates',
                          value: '...',
                          icon: Icons.description_rounded,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.pushNamed(RouteNames.templates),
                        ),
                        error: (_, __) => _StatCard(
                          title: 'Templates',
                          value: '0',
                          icon: Icons.description_rounded,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.pushNamed(RouteNames.templates),
                        ),
                        data: (templates) => _StatCard(
                          title: 'Templates',
                          value: '${templates.length}',
                          icon: Icons.description_rounded,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.pushNamed(RouteNames.templates),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),


        // ============ QUICK ACTIONS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: AppDimens.sm),
                  child: Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.send_rounded,
                        label: 'Send',
                        color: const Color(0xFF6366F1),
                        onTap: () => context.pushNamed(RouteNames.newMessage),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.description_rounded,
                        label: 'Template',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.pushNamed(RouteNames.templates),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.diamond_rounded,
                        label: 'Plans',
                        color: const Color(0xFF0891B2),
                        onTap: () => context.pushNamed(RouteNames.plans),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.groups_rounded,
                        label: 'Agents',
                        color: const Color(0xFFEC4899),
                        onTap: () => context.pushNamed(RouteNames.agents),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        color: const Color(0xFF7C3AED),
                        onTap: () => context.pushNamed(RouteNames.settings),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.phone_rounded,
                        label: 'Calls',
                        color: const Color(0xFF25D366),
                        onTap: () => context.pushNamed(RouteNames.callHistory),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.analytics_rounded,
                        label: 'Analytics',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.pushNamed('analytics-dashboard'),
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: (user?.aiBotEnabled ?? false) && user?.dataOwner == null
                          ? _QuickActionCard(
                              icon: Icons.smart_toy_rounded,
                              label: 'AI Bot',
                              color: const Color(0xFF10B981),
                              onTap: () => context.pushNamed(RouteNames.aiBotSettings),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    const Expanded(child: SizedBox()), // spacer
                  ],
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.sm)),

        // ============ MESSAGING LIMIT (Real-time from Meta API) ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
            child: ref.watch(whatsappInsightsProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (insights) {
                if (insights.isEmpty) return const SizedBox.shrink();

                final limit = insights['messaging_limit'] as Map<String, dynamic>? ?? {};
                final limitCount = (limit['limit'] as num?)?.toInt() ?? 0;
                final tierRaw = limit['raw'] ?? 'TIER_NOT_SET';

                // Tier progression
                final tiers = [
                  {'label': '250', 'key': 'TIER_250', 'value': 250},
                  {'label': '1K', 'key': 'TIER_1K', 'value': 1000},
                  {'label': '2K', 'key': 'TIER_2K', 'value': 2000},
                  {'label': '10K', 'key': 'TIER_10K', 'value': 10000},
                  {'label': '100K', 'key': 'TIER_100K', 'value': 100000},
                  {'label': 'âˆž', 'key': 'UNLIMITED', 'value': -1},
                ];

                return _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.speed_rounded, size: 16, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Messaging Limit',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Chip(label: 'Meta API', color: const Color(0xFF25D366)),
                        ],
                      ),
                      const SizedBox(height: AppDimens.md),

                      // Current usage highlight
                      Builder(builder: (context) {
                        final usage24h = insights['usage_24h'] as Map<String, dynamic>? ?? {};
                        final sent = (usage24h['sent'] as num?)?.toInt() ?? 0;
                        final percentage = limitCount <= 0 ? 0.0 : (sent / limitCount).clamp(0.0, 1.0);
                        final isUnlimited = limitCount == -1;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary.withAlpha(15), AppColors.primary.withAlpha(5)],
                            ),
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            border: Border.all(color: AppColors.primary.withAlpha(30)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isUnlimited ? 'Unlimited' : '$sent / $limitCount used',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    isUnlimited ? 'âˆž' : '${(percentage * 100).toInt()}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: percentage > 0.8
                                          ? Colors.red
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (!isUnlimited) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    minHeight: 6,
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      percentage > 0.8 ? Colors.red : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Last 24 hours \u2022 Meta API',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: AppDimens.sm),

                      // Tier progression row
                      Row(
                        children: tiers.map((tier) {
                          final isActive = tier['key'] == tierRaw;
                          final isPassed = (tierRaw == 'UNLIMITED') ||
                              (limitCount != -1 && (tier['value'] as int) != -1 && (tier['value'] as int) <= limitCount);

                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary
                                    : isPassed
                                        ? AppColors.primary.withAlpha(30)
                                        : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                border: isActive
                                    ? null
                                    : Border.all(
                                        color: isPassed ? AppColors.primary.withAlpha(50) : Colors.transparent,
                                      ),
                              ),
                              child: Text(
                                tier['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : isPassed
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // View Insights link
                      const SizedBox(height: AppDimens.sm),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // ============ PHONE HEALTH ============
        SliverToBoxAdapter(
          child: _PhoneHealthCard(),
        ),

        // ============ RECENT CONVERSATIONS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppDimens.md, AppDimens.lg, AppDimens.md, AppDimens.sm),
            child: Row(
              children: [
                Text(
                  'Recent Chats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.goNamed(RouteNames.messages),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Row(
                    children: [
                      Text('See All'),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: conversationsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(AppDimens.xl),
                child: CircularProgressIndicator(),
              )),
              error: (_, __) => const SizedBox.shrink(),
              data: (convs) {
                if (convs.isEmpty) {
                  return _SectionCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.xl),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: theme.colorScheme.onSurface.withAlpha(30),
                            ),
                            const SizedBox(height: AppDimens.sm),
                            Text(
                              'No conversations yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Re-sort by lastMessageAt for dashboard (ignore pin â€” pins only in inbox)
                final recentConvs = List<ConversationModel>.from(convs)
                  ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

                final nameMap = ref.watch(contactNameMapProvider);
                return _SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: recentConvs.take(5).map((conv) {
                      final isLast = recentConvs.indexOf(conv) == min(4, recentConvs.length - 1);
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 4),
                            leading: Stack(
                              children: [
                                WbAvatar(
                                  name: _resolveDisplayName(conv, nameMap),
                                  size: AppDimens.avatarMd,
                                ),
                                if (conv.unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              _resolveDisplayName(conv, nameMap),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conv.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: conv.unreadCount > 0 
                                        ? theme.colorScheme.onSurface 
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                if (conv.tags.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Builder(builder: (context) {
                                    final tagsData = ref.watch(userTagsProvider).valueOrNull ?? [];
                                    final tagMap = <String, Color>{};
                                    for (final t in tagsData) {
                                      final n = t['name'] ?? '';
                                      tagMap[n] = _parseTagColorHex(t['color']);
                                    }
                                    return Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: conv.tags.take(3).map((tag) {
                                        final c = tagMap[tag] ?? AppColors.primary;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: c.withAlpha(25),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: c.withAlpha(80)),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: c,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }),
                                ],
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatConvTime(conv.lastMessageAt),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: conv.unreadCount > 0
                                        ? AppColors.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                                if (conv.unreadCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                                    ),
                                    child: Text(
                                      '${conv.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                                if (conv.lastIncomingMessageAt != null && conv.isReplyWindowOpen) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withAlpha(20),
                                      borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                                    ),
                                    child: Text(
                                      'Free',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.info,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => context.pushNamed(
                              RouteNames.chat,
                              pathParameters: {'phone': conv.contactPhone},
                              extra: _resolveDisplayName(conv, nameMap),
                            ),
                            onLongPress: () => _showConvContextMenu(context, ref, conv),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 70,
                              endIndent: AppDimens.md,
                              color: theme.colorScheme.outlineVariant.withAlpha(50),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),

        // ============ ANTI-BAN TIPS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.md),
            child: Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(isDark ? 10 : 15),
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                border: Border.all(color: AppColors.primary.withAlpha(isDark ? 20 : 30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_moon_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Anti-Ban Safety Tips',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sm),
                  _SafetyTip(text: 'Use approved templates for first-time messages.'),
                  _SafetyTip(text: 'Avoid sending identical texts to many contacts.'),
                  _SafetyTip(text: 'Maintain a natural sending rhythm (max 20/min).'),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.huge)),
      ],
    );
  }
  /// Resolve display name: saved contact name > WhatsApp profile name > phone
  String _resolveDisplayName(ConversationModel conv, Map<String, String> nameMap) {
    final rawName = conv.contactName;
    final phone = conv.contactPhone;
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final isPhoneName = rawName == phone || rawName == phoneDigits ||
        rawName.replaceAll(RegExp(r'[^0-9]'), '') == phoneDigits;
    return isPhoneName ? (nameMap[phoneDigits] ?? nameMap['+$phoneDigits'] ?? rawName) : rawName;
  }

  String _greeting() {
    final now = DateTime.now().toLocal();
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'Good morning \u2600';
    if (hour >= 12 && hour < 17) return 'Good afternoon \u{1F324}';
    if (hour >= 17 && hour < 21) return 'Good evening \u{1F319}';
    return 'Good night \u{1F634}';
  }


  void _showConvContextMenu(BuildContext context, WidgetRef ref, ConversationModel conv) {
    final repo = ref.read(messageRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ownerId = user.dataOwner ?? user.id;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_resolveDisplayName(conv, ref.read(contactNameMapProvider)), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primary),
              title: Text(conv.isPinned ? 'Unpin Conversation' : 'Pin Conversation'),
              subtitle: conv.isPinned ? null : const Text('Max 3 pinned conversations'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await repo.togglePin(ownerId, conv.contactPhone);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maximum 3 conversations can be pinned')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline, color: AppColors.primary),
              title: const Text('Manage Tags'),
              onTap: () {
                Navigator.pop(ctx);
                _showTagDialog(context, ref, conv);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTagDialog(BuildContext context, WidgetRef ref, ConversationModel conv) {
    final repo = ref.read(messageRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ownerId = user.dataOwner ?? user.id;
    final newTagController = TextEditingController();
    Color selectedColor = const Color(0xFF4CAF50);

    const tagColors = [
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF5722),
      Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF009688),
      Color(0xFFE91E63), Color(0xFF607D8B), Color(0xFF795548),
      Color(0xFF3F51B5),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final tagsAsync = ref.watch(userTagsProvider);
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.label, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(child: Text('Manage Tags')),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTagController,
                            decoration: const InputDecoration(
                              hintText: 'New tag name...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                          onPressed: () {
                            final name = newTagController.text.trim();
                            if (name.isNotEmpty) {
                              final hex = '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              repo.createTag(ownerId, name, hex);
                              newTagController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: tagColors.map((c) {
                        final isSelected = c == selectedColor;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                              boxShadow: isSelected ? [BoxShadow(color: c.withAlpha(120), blurRadius: 6)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    tagsAsync.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (tags) {
                        if (tags.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No tags yet. Create one above!', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView(
                            shrinkWrap: true,
                            children: tags.map((tag) {
                              final tagName = tag['name'] ?? '';
                              final tagColorStr = tag['color'];
                              final tagColor = _parseTagColorHex(tagColorStr);
                              final isApplied = conv.tags.contains(tagName);
                              return CheckboxListTile(
                                title: Row(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tagName)),
                                  ],
                                ),
                                value: isApplied,
                                fillColor: WidgetStateProperty.resolveWith((states) => tagColor),
                                dense: true,
                                secondary: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Tag'),
                                        content: Text('Delete "$tagName"? It will be removed from all conversations.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) repo.deleteTag(ownerId, tag['id']);
                                  },
                                ),
                                onChanged: (checked) {
                                  if (checked == true) {
                                    repo.addTag(ownerId, conv.contactPhone, tagName);
                                  } else {
                                    repo.removeTag(ownerId, conv.contactPhone, tagName);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Color _parseTagColorHex(dynamic colorValue) {
    if (colorValue == null) return AppColors.primary;
    if (colorValue is String && colorValue.startsWith('#') && colorValue.length >= 7) {
      try {
        return Color(int.parse('FF${colorValue.substring(1)}', radix: 16));
      } catch (_) {
        return AppColors.primary;
      }
    }
    return AppColors.primary;
  }

  String _formatConvTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ================================================================
// ==================== ADMIN DASHBOARD =========================
// ================================================================
class _AdminDashboard extends ConsumerStatefulWidget {
  final dynamic user;
  const _AdminDashboard({required this.user});

  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  final _announcementCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _downloadUrlCtrl = TextEditingController();
  final _masterPromptCtrl = TextEditingController();

  @override
  void dispose() {
    _announcementCtrl.dispose();
    _minVersionCtrl.dispose();
    _downloadUrlCtrl.dispose();
    _masterPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(liveStatsProvider);
    final pendingSubsAsync = ref.watch(pendingSubscriptionsProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ============ PREMIUM ADMIN HERO ============
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
                    : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppDimens.radiusXl),
                bottomRight: Radius.circular(AppDimens.radiusXl),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF6366F1)).withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimens.xs),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppDimens.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Console',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Platform Control Center',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _NotificationBadge(isAdmin: true),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.md)),

        // ============ QUICK ACTIONS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppDimens.sm),
                Row(
                  children: [
                    _buildQuickAction(Icons.campaign_rounded, 'Announce', const Color(0xFFEC4899),
                        () => _showAnnouncementDialog()),
                    const SizedBox(width: AppDimens.xs),
                    _buildQuickAction(Icons.system_update_rounded, 'App Update', const Color(0xFF0EA5E9),
                        () => _showForceUpdateDialog()),
                    const SizedBox(width: AppDimens.xs),
                    _buildQuickAction(Icons.smart_toy_rounded, 'AI Bot', const Color(0xFF10B981),
                        () => _showMasterPromptDialog()),
                    const SizedBox(width: AppDimens.xs),
                    _buildQuickAction(Icons.support_agent_rounded, 'Support', const Color(0xFF8B5CF6),
                        () => context.pushNamed('admin-support')),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.md)),

        // ============ ADMIN STATS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: statsAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(AppDimens.xl),
                  child: CircularProgressIndicator(),
                )),
                error: (_, __) => const _ErrorCard(message: 'Error loading platform stats'),
                data: (stats) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Users',
                            value: '${stats['totalUsers'] ?? 0}',
                            icon: Icons.people_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: AppDimens.xs),
                        Expanded(
                          child: _StatCard(
                            title: 'Active',
                            value: '${stats['activeUsers'] ?? 0}',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: AppDimens.xs),
                        Expanded(
                          child: _StatCard(
                            title: 'Pending',
                            value: '${stats['pendingUsers'] ?? 0}',
                            icon: Icons.pending_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Messages',
                            value: '${stats['totalMessages'] ?? 0}',
                            icon: Icons.message_rounded,
                            color: const Color(0xFF0EA5E9),
                          ),
                        ),
                        const SizedBox(width: AppDimens.xs),
                        Expanded(
                          child: _StatCard(
                            title: 'Connected',
                            value: '${stats['connectedUsers'] ?? 0}',
                            icon: Icons.link_rounded,
                            color: const Color(0xFF25D366),
                          ),
                        ),
                        const SizedBox(width: AppDimens.xs),
                        Expanded(
                          child: _StatCard(
                            title: 'Suspended',
                            value: '${stats['suspendedUsers'] ?? 0}',
                            icon: Icons.block_rounded,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ============ PENDING SUBSCRIPTIONS ============
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimens.lg),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: AppDimens.sm),
                  child: Text(
                    'Pending Approvals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                pendingSubsAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(AppDimens.xl),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => _ErrorCard(message: 'Error: $e'),
                  data: (subs) {
                    if (subs.isEmpty) {
                      return _SectionCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimens.xl),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurface.withAlpha(30),
                                ),
                                const SizedBox(height: AppDimens.sm),
                                Text(
                                  'No pending subscriptions',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: subs.map((data) {
                        final sub = data['subscription'] as SubscriptionModel;
                        final userId = data['userId'] as String;
                        final userName = (data['userName'] as String? ?? '').trim();
                        final userEmail = (data['userEmail'] as String? ?? '').trim();
                        final userPhone = (data['userPhone'] as String? ?? '').trim();
                        final requestedAt = data['requestedAt'] as DateTime?;
                        final displayName = userName.isNotEmpty ? userName : 'User ...${userId.substring(max(0, userId.length - 6))}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimens.sm),
                          child: _SectionCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.orange.withAlpha(25),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                                  title: Text(
                                    userName.isNotEmpty ? userName : 'Unknown User',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      // User ID row
                                      Row(
                                        children: [
                                          Icon(Icons.fingerprint_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              userId,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontFamily: 'monospace',
                                                fontSize: 10,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Email row
                                      if (userEmail.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.email_outlined, size: 12, color: theme.colorScheme.primary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                userEmail,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      // Phone row
                                      if (userPhone.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 12, color: Colors.green.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              userPhone,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.green.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                                        onPressed: () async {
                                          final confirm = await WbDialog.showConfirm(
                                            context,
                                            title: 'Approve Plan',
                                            message: 'Activate ${sub.planName} plan for $displayName?',
                                          );
                                          if (confirm) {
                                            ref.read(planNotifierProvider.notifier).activateSubscription(userId);
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
                                        onPressed: () async {
                                          final confirm = await WbDialog.showConfirm(
                                            context,
                                            title: 'Reject Plan',
                                            message: 'Reject subscription request from $displayName?',
                                            isDanger: true,
                                          );
                                          if (confirm) {
                                            ref.read(planNotifierProvider.notifier).rejectSubscription(userId);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Plan name + request time row
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppDimens.md, 0, AppDimens.md, AppDimens.sm),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.orange.withAlpha(40)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.card_membership_rounded, color: Colors.orange, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              sub.planName,
                                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      if (requestedAt != null)
                                        Text(
                                          _formatRequestTime(requestedAt),
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
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.huge)),
      ],
    );
  }

  // ============ FORMAT REQUEST TIME ============
  String _formatRequestTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ============ QUICK ACTION BUTTON BUILDER ============
  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
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
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ============ ANNOUNCEMENT DIALOG ============
  void _showAnnouncementDialog() {
    _announcementCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.campaign_rounded, color: Color(0xFFEC4899)),
          SizedBox(width: 8), Text('Send Announcement'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This will be shown to ALL users.'),
          const SizedBox(height: 12),
          TextField(controller: _announcementCtrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Enter announcement...', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            final msg = _announcementCtrl.text.trim();
            if (msg.isEmpty) return;
            await FirebaseFirestore.instance.collection('config').doc('announcement').set({
              'message': msg, 'active': true, 'createdAt': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sent âœ…')));
            }
          }, child: const Text('Send')),
        ],
      ),
    );
  }

  // ============ FORCE UPDATE DIALOG ============
  void _showForceUpdateDialog() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_version').get();
      final data = doc.data() ?? {};
      _minVersionCtrl.text = data['minVersion'] ?? '1.1.3';
      _downloadUrlCtrl.text = data['downloadUrl'] ?? 'https://wabees.live';
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.system_update_rounded, color: Color(0xFF0EA5E9)),
          SizedBox(width: 8), Text('Force Update'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _minVersionCtrl, decoration: const InputDecoration(labelText: 'Min Version', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _downloadUrlCtrl, decoration: const InputDecoration(labelText: 'Download URL', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('config').doc('app_version').set({
              'minVersion': _minVersionCtrl.text.trim(),
              'downloadUrl': _downloadUrlCtrl.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Saved âœ…')));
            }
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  // ============ AI BOT MASTER PROMPT DIALOG ============
  void _showMasterPromptDialog() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('ai_bot_master').get();
      _masterPromptCtrl.text = (doc.data() ?? {})['masterPrompt'] ?? '';
    } catch (_) {
      _masterPromptCtrl.text = '';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981)),
          SizedBox(width: 8), Expanded(child: Text('AI Bot Master Prompt')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Global instructions for ALL users\' AI bots.'),
          const SizedBox(height: 12),
          TextField(controller: _masterPromptCtrl, maxLines: 8,
            decoration: const InputDecoration(hintText: 'e.g. Never share private data...', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('app_config').doc('ai_bot_master').set({
              'masterPrompt': _masterPromptCtrl.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Master prompt saved âœ…')));
            }
          }, child: const Text('Save')),
        ],
      ),
    );
  }
}

// ================================================================
// ==================== HELPER WIDGETS ==========================
// ================================================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withAlpha(isDark ? 20 : 12),
              color.withAlpha(isDark ? 8 : 5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(isDark ? 40 : 25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isDark ? 8 : 15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withAlpha(40),
                        color.withAlpha(20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withAlpha(isDark ? 18 : 12),
              color.withAlpha(isDark ? 8 : 4),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(isDark ? 30 : 20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(35), color.withAlpha(15)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? color.withAlpha(200) : color,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  final String text;
  const _SafetyTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppStatusBadge extends StatelessWidget {
  final bool connected;
  const _WhatsAppStatusBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.whatsappConnection),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (connected ? Colors.greenAccent : Colors.redAccent).withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(
                connected ? Icons.link_rounded : Icons.link_off_rounded,
                size: 18,
                color: connected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'WhatsApp API Connected' : 'WhatsApp Disconnected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    connected ? 'Meta Business API is active' : 'Tap to set up your connection',
                    style: TextStyle(
                      color: Colors.white.withAlpha(160),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _NotificationBadge extends ConsumerWidget {
  final bool isAdmin;
  const _NotificationBadge({required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = isAdmin 
      ? ref.watch(adminNotificationUnreadProvider).valueOrNull ?? 0
      : ref.watch(userNotificationUnreadProvider).valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => context.pushNamed('notifications', extra: isAdmin),
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0A1628), width: 1.5),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
// ================================================================
// ==================== PHONE HEALTH CARD ==========================
// ================================================================
class _PhoneHealthCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(whatsappConnectedProvider);
    if (!isConnected) return const SizedBox.shrink();

    final healthAsync = ref.watch(phoneHealthProvider);

    return healthAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (health) {
        if (health.isEmpty) return const SizedBox.shrink();

        final qualityRating = health['quality_rating'] ?? 'UNKNOWN';
        final tier = health['messaging_limit_tier'] ?? 'UNKNOWN';
        final status = health['status'] ?? 'UNKNOWN';
        final verifiedName = health['verified_name'] ?? '';
        final displayPhone = health['display_phone_number'] ?? '';

        Color qualityColor;
        IconData qualityIcon;
        switch (qualityRating.toString().toUpperCase()) {
          case 'GREEN':
            qualityColor = const Color(0xFF10B981);
            qualityIcon = Icons.check_circle;
            break;
          case 'YELLOW':
            qualityColor = const Color(0xFFF59E0B);
            qualityIcon = Icons.warning_rounded;
            break;
          case 'RED':
            qualityColor = const Color(0xFFEF4444);
            qualityIcon = Icons.error_rounded;
            break;
          default:
            qualityColor = Colors.grey;
            qualityIcon = Icons.help_outline;
        }

        String tierLabel;
        final tierStr = (tier ?? '').toString().toUpperCase().trim();
        if (tierStr.isEmpty || tierStr == 'UNKNOWN' || tierStr == 'TIER_NOT_SET') {
          tierLabel = 'Default (250/day)';
        } else if (tierStr == 'TIER_50' || tierStr == '50') {
          tierLabel = '50/day';
        } else if (tierStr == 'TIER_250' || tierStr == '250') {
          tierLabel = '250/day';
        } else if (tierStr == 'TIER_1K' || tierStr == '1K') {
          tierLabel = '1,000/day';
        } else if (tierStr == 'TIER_10K' || tierStr == '10K') {
          tierLabel = '10,000/day';
        } else if (tierStr == 'TIER_100K' || tierStr == '100K') {
          tierLabel = '100,000/day';
        } else {
          // Fallback: strip TIER_ prefix and make readable
          tierLabel = tierStr.replaceAll('TIER_', '').replaceAll('_', ' ');
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppDimens.md, AppDimens.sm, AppDimens.md, 0),
          child: _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Phone Health',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.md),
                // Quality rating
                Row(
                  children: [
                    Icon(qualityIcon, color: qualityColor, size: 18),
                    const SizedBox(width: 8),
                    Text('Quality: ', style: theme.textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: qualityColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qualityRating.toString().toUpperCase(),
                        style: TextStyle(
                          color: qualityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('Status: ', style: theme.textTheme.bodySmall),
                    Text(
                      status.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: status == 'CONNECTED' ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                // Tier + verified name
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Text('Limit: $tierLabel', style: theme.textTheme.bodySmall),
                    if (verifiedName.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.verified, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          verifiedName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (displayPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    displayPhone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}


