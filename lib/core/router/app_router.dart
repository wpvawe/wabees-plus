import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/auth_state.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/shared/main_shell.dart';
import '../../screens/shared/dashboard/dashboard_screen.dart';
import '../../screens/shared/profile/profile_screen.dart';
import '../../screens/shared/settings/settings_screen.dart';
import '../../screens/shared/whatsapp/whatsapp_connection_screen.dart';
import '../../screens/shared/messaging/inbox_screen.dart';
import '../../screens/shared/messaging/chat_screen.dart';
import '../../screens/shared/messaging/new_message_screen.dart';
import '../../screens/shared/contacts/contacts_screen.dart';
import '../../screens/shared/contacts/add_contact_screen.dart';
import '../../screens/shared/templates/templates_screen.dart';
import '../../screens/shared/templates/template_builder_screen.dart';
import '../../data/models/contact/contact_model.dart';
import '../../data/models/bot/bot_model.dart';
import '../../data/models/template/template_model.dart';
import '../../screens/shared/bots/bots_screen.dart';
import '../../screens/shared/agents/agents_screen.dart';
import '../../screens/shared/bots/bot_builder_screen.dart';
import '../../screens/shared/bots/ai_bot_settings_screen.dart';
import '../../screens/shared/settings/business_profile_screen.dart';
import '../../data/models/campaign/campaign_model.dart';
import '../../screens/shared/campaigns/campaigns_screen.dart';
import '../../screens/shared/campaigns/campaign_builder_screen.dart';
import '../../screens/shared/campaigns/campaign_detail_screen.dart';
import '../../screens/shared/campaigns/campaign_analytics_screen.dart';

import '../../screens/shared/plans/plans_screen.dart';
import '../../screens/admin/admin_plans_screen.dart';

import '../../screens/admin/admin_users_screen.dart';
import '../../screens/admin/admin_user_detail_screen.dart';
import '../../screens/shared/settings/notification_settings_screen.dart';
import '../../screens/shared/support/support_chat_screen.dart';
import '../../screens/shared/notifications/notifications_screen.dart';
import '../../screens/admin/admin_support_screen.dart';
import '../../screens/shared/whatsapp/message_links_screen.dart';
import '../../screens/shared/analytics/analytics_screen.dart';
import '../../screens/shared/analytics/analytics_dashboard_screen.dart';
import '../../screens/shared/calling/call_history_screen.dart';
import '../../screens/shared/calling/in_call_screen.dart';
import '../../screens/shared/profile/diagnostic_screen.dart';
import '../../data/models/user/user_model.dart';
import '../../data/models/user/user_status.dart';
import '../../screens/auth/pending_approval_screen.dart';
import 'route_names.dart';

/// 🔄 AUTH CHANGE NOTIFIER — Bridges Riverpod → GoRouter refreshListenable
/// Notifies when isAuthenticated, isLoading, OR user status changes.
class AuthChangeNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _userStatus; // Track status to react to pending→active changes

  void update(AuthState state) {
    final newAuth = state.isAuthenticated;
    final newLoading = state.isLoading;
    final newStatus = state.user?.status.name;

    // Notify GoRouter when auth STATUS or user approval status changes
    if (newAuth != _isAuthenticated || newLoading != _isLoading || newStatus != _userStatus) {
      _isAuthenticated = newAuth;
      _isLoading = newLoading;
      _userStatus = newStatus;
      notifyListeners();
    }
  }
}

/// 🔑 Riverpod provider for the auth change notifier
final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();

  // Listen to auth state and forward ONLY status changes
  ref.listen(authNotifierProvider, (prev, next) {
    notifier.update(next);
  });

  return notifier;
});

/// 🚀 APP ROUTER - GoRouter Config (created ONCE, never rebuilt)
final appRouterProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.read(authChangeNotifierProvider);

  // Trigger initial state
  authChangeNotifier.update(ref.read(authNotifierProvider));

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,

    // GoRouter listens to this — only fires when auth STATUS changes
    refreshListenable: authChangeNotifier,

    redirect: (context, state) {
      // READ current auth state (not watch — avoids rebuilding GoRouter)
      final authState = ref.read(authNotifierProvider);
      final isAuth = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final userStatus = authState.user?.status;
      final location = state.matchedLocation;

      // Auth routes (login, register, forgot-password)
      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';

      // Still loading (initial app startup) — show splash ONLY if not on auth routes
      if (isLoading && !isAuth) {
        if (isAuthRoute) return null;
        if (location != '/') return '/';
        return null;
      }

      // Done loading — redirect from splash to appropriate page
      if (location == '/') {
        if (!isAuth) return '/login';
        if (userStatus != null && (userStatus.isSuspended || userStatus == UserStatus.deactivated)) {
          // Suspended/deactivated: the real-time listener will call logout() shortly.
          // Don't redirect to /login while isAuth=true (infinite loop). Stay on splash.
          return null;
        }
        if (userStatus != null && userStatus.isPending) return '/pending-approval';
        return '/dashboard';
      }

      // Not authenticated — redirect to login
      if (!isAuth && !isAuthRoute) return '/login';

      // Authenticated but on auth route — check status
      if (isAuth && isAuthRoute) {
        if (userStatus != null && (userStatus.isSuspended || userStatus == UserStatus.deactivated)) {
          // Let them stay on auth route — logout is in progress
          return null;
        }
        if (userStatus != null && userStatus.isPending) return '/pending-approval';
        return '/dashboard';
      }

      // Authenticated user with pending/suspended status — block all app routes
      if (isAuth && userStatus != null) {
        if (userStatus.isSuspended || userStatus == UserStatus.deactivated) {
          // Logout is triggered by _listenToUserChanges — stay put to avoid loop
          return null;
        }
        if (userStatus.isPending && location != '/pending-approval') {
          return '/pending-approval';
        }
      }

      return null;
    },

    routes: [
      // ============ SPLASH ============
      GoRoute(
        path: '/',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ============ AUTH ROUTES ============
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ============ PENDING APPROVAL (accessible without active status) ============
      GoRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // ============ MAIN SHELL (Bottom Nav) ============
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: RouteNames.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/messages',
            name: RouteNames.messages,
            builder: (context, state) => const InboxScreen(),
          ),
          GoRoute(
            path: '/contacts',
            name: RouteNames.contacts,
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: RouteNames.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ============ STANDALONE SCREENS (no bottom nav) ============
      GoRoute(
        path: '/whatsapp-connection',
        name: RouteNames.whatsappConnection,
        builder: (context, state) => const WhatsappConnectionScreen(),
      ),
      GoRoute(
        path: '/chat/:phone',
        name: RouteNames.chat,
        builder: (context, state) {
          final phone = state.pathParameters['phone'] ?? '';
          final name = state.extra as String? ?? phone;
          return ChatScreen(contactPhone: phone, contactName: name);
        },
      ),
      GoRoute(
        path: '/new-message',
        name: RouteNames.newMessage,
        builder: (context, state) => const NewMessageScreen(),
      ),
      GoRoute(
        path: '/add-contact',
        name: RouteNames.addContact,
        builder: (context, state) {
          final contact = state.extra as ContactModel?;
          return AddContactScreen(existingContact: contact);
        },
      ),
      GoRoute(
        path: '/templates',
        name: RouteNames.templates,
        builder: (context, state) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/template-builder',
        name: RouteNames.templateBuilder,
        builder: (context, state) {
          final template = state.extra as TemplateModel?;
          return TemplateBuilderScreen(existingTemplate: template);
        },
      ),
      GoRoute(
        path: '/bots',
        name: RouteNames.bots,
        builder: (context, state) => const BotsScreen(),
      ),
      GoRoute(
        path: '/bot-builder',
        name: RouteNames.botBuilder,
        builder: (context, state) {
          final bot = state.extra as BotModel?;
          return BotBuilderScreen(existingBot: bot);
        },
      ),
      GoRoute(
        path: '/ai-bot-settings',
        name: RouteNames.aiBotSettings,
        builder: (context, state) => const AiBotSettingsScreen(),
      ),
      GoRoute(
        path: '/campaigns',
        name: RouteNames.campaigns,
        builder: (context, state) => const CampaignsScreen(),
      ),
      GoRoute(
        path: '/campaign-builder',
        name: RouteNames.campaignBuilder,
        builder: (context, state) {
          final campaign = state.extra as CampaignModel?;
          return CampaignBuilderScreen(existingCampaign: campaign);
        },
      ),
      GoRoute(
        path: '/campaign-detail',
        name: RouteNames.campaignDetail,
        builder: (context, state) {
          final campaignId = state.extra as String;
          return CampaignDetailScreen(campaignId: campaignId);
        },
      ),
      GoRoute(
        path: '/campaign-analytics',
        name: RouteNames.campaignAnalytics,
        builder: (context, state) => const CampaignAnalyticsScreen(),
      ),
      GoRoute(
        path: '/plans',
        name: RouteNames.adminPlans,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: '/admin-plans',
        name: 'admin-plans-manage',
        builder: (context, state) => const AdminPlansScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        name: 'admin-dashboard',
        redirect: (context, state) => '/dashboard',
      ),
      GoRoute(
        path: '/admin-users',
        name: RouteNames.adminUsers,
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin-user-detail',
        name: 'admin-user-detail',
        builder: (context, state) {
          final extra = state.extra;
          // Can receive either UserModel directly or String userId
          if (extra is UserModel) {
            return AdminUserDetailScreen(user: extra);
          }
          // Fallback: userId string — screen must fetch user internally
          // This happens when navigating from pending subscriptions card
          final userId = extra as String? ?? '';
          return AdminUserDetailScreen.fromId(userId: userId);
        },
      ),
      GoRoute(
        path: '/notification-settings',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      GoRoute(
        path: '/view-plans',
        name: RouteNames.plans,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: '/support-chat',
        name: RouteNames.support,
        builder: (context, state) {
          final initialMessage = state.extra as String?;
          return SupportChatScreen(initialMessage: initialMessage);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) {
          final isAdmin = state.extra as bool? ?? false;
          return NotificationsScreen(isAdmin: isAdmin);
        },
      ),
      GoRoute(
        path: '/admin-support',
        name: 'admin-support',
        builder: (context, state) => const AdminSupportScreen(),
      ),
      GoRoute(
        path: '/message-links',
        name: RouteNames.messageLinks,
        builder: (context, state) => const MessageLinksScreen(),
      ),
      GoRoute(
        path: '/analytics',
        name: RouteNames.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/business-profile',
        name: RouteNames.businessProfile,
        builder: (context, state) => const BusinessProfileScreen(),
      ),
      GoRoute(
        path: '/diagnostics',
        name: RouteNames.diagnostics,
        builder: (context, state) => const DiagnosticScreen(),
      ),
      GoRoute(
        path: '/agents',
        name: RouteNames.agents,
        builder: (context, state) => const AgentsScreen(),
      ),
      GoRoute(
        path: '/call-history',
        name: RouteNames.callHistory,
        builder: (context, state) => const CallHistoryScreen(),
      ),
      GoRoute(
        path: '/in-call',
        name: RouteNames.inCall,
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return InCallScreen(
            callId: args['callId'] ?? '',
            contactName: args['contactName'] ?? '',
            contactPhone: args['contactPhone'] ?? '',
            isIncoming: args['isIncoming'] ?? false,
            ownerId: args['ownerId'] as String?,
            sdpAnswer: args['sdpAnswer'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/analytics-dashboard',
        name: 'analytics-dashboard',
        builder: (context, state) => const AnalyticsDashboardScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
