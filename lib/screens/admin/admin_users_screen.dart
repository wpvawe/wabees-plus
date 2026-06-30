import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../data/models/user/user_status.dart';
import '../../../providers/admin/admin_provider.dart';

/// 🛡️ ADMIN USERS SCREEN — Manage all platform users
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('admin-dashboard');
            }
          },
        ),
        title: const Text('User Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Active'),
                  Tab(text: 'Suspended'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: usersAsync.when(
        loading: () => const WbLoading(message: 'Loading users...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allUsers) {
          // Apply search filter
          final filtered = _searchQuery.isEmpty
              ? allUsers
              : allUsers.where((u) {
                  final q = _searchQuery;
                  return u.businessName.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q) ||
                      u.phone.toLowerCase().contains(q) ||
                      u.id.toLowerCase().contains(q);
                }).toList();

          final pending = filtered.where((u) => u.status == UserStatus.pending).toList();
          final active = filtered.where((u) => u.status == UserStatus.active).toList();
          final suspended = filtered.where((u) => u.status == UserStatus.suspended).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _UserList(users: filtered, ref: ref, theme: theme),
              _UserList(users: pending, ref: ref, theme: theme),
              _UserList(users: active, ref: ref, theme: theme),
              _UserList(users: suspended, ref: ref, theme: theme),
            ],
          );
        },
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List users;
  final WidgetRef ref;
  final ThemeData theme;

  const _UserList({
    required this.users,
    required this.ref,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const WbEmptyState(
        message: 'No users in this category',
        icon: Icons.people_outline,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.md),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimens.xs),
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            onTap: () => context.pushNamed('admin-user-detail', extra: user),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor: _statusColor(user.status).withAlpha(30),
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? Icon(Icons.person,
                            color: _statusColor(user.status))
                        : null,
                  ),
                  const SizedBox(width: AppDimens.sm),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.businessName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusBadge(status: user.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _MiniStat(
                              icon: Icons.message,
                              value: '${user.totalMessages}',
                            ),
                            const SizedBox(width: AppDimens.md),
                            _MiniStat(
                              icon: Icons.contacts,
                              value: '${user.totalContacts}',
                            ),
                            const SizedBox(width: AppDimens.md),
                            if (user.whatsappConnected)
                              Icon(Icons.check_circle,
                                  size: 14, color: Colors.green.shade600),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleAction(context, action, user, ref),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    dynamic user,
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

  Color _statusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.pending:
        return Colors.orange;
      case UserStatus.suspended:
        return Colors.red;
      case UserStatus.deactivated:
        return Colors.grey;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final UserStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case UserStatus.active:
        color = Colors.green;
      case UserStatus.pending:
        color = Colors.orange;
      case UserStatus.suspended:
        color = Colors.red;
      case UserStatus.deactivated:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
