import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/display/wb_avatar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../providers/auth/auth_provider.dart';

/// 👤 PROFILE SCREEN — VIP PREMIUM REDESIGN
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _businessNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _isEditing = true;
      _businessNameController.text = user.businessName;
      _phoneController.text = user.phoneNumber;
    });
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final newName = _businessNameController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newName.isEmpty) {
      WbSnackbar.showError(context, 'Business name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{};

      if (newName != user.businessName) {
        updates['businessName'] = newName;
      }

      // Phone can only be set once (if it was empty before)
      if (user.phoneNumber.isEmpty && newPhone.isNotEmpty) {
        updates['phoneNumber'] = newPhone;
      }

      if (updates.isNotEmpty) {
        await ref.read(userRepositoryProvider).updateUser(user.id, updates);
        if (mounted) {
          WbSnackbar.showSuccess(context, 'Profile updated successfully');
        }
      }

      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Failed to update profile');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final phoneEmpty = user.phoneNumber.isEmpty;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ============ PREMIUM GRADIENT HEADER ============
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 40,
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
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.goNamed(RouteNames.dashboard),
                        ),
                        const Expanded(
                          child: Text(
                            'My Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Edit / Save button
                        if (!_isEditing)
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                            onPressed: _startEditing,
                            tooltip: 'Edit Profile',
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54),
                                onPressed: _isSaving ? null : _cancelEditing,
                                tooltip: 'Cancel',
                              ),
                              IconButton(
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, color: Colors.white),
                                onPressed: _isSaving ? null : _saveProfile,
                                tooltip: 'Save',
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Avatar with ring
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: WbAvatar(
                      name: user.businessName,
                      imageUrl: user.profileImageUrl,
                      size: 90,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    user.businessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.role.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.role.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ============ PROFILE INFO CARDS ============
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Account Info
                  _buildSectionHeader(theme, 'Account Information', Icons.person_rounded),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    theme: theme,
                    isDark: isDark,
                    children: [
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.business_rounded,
                        label: 'Business Name',
                        value: user.businessName,
                        isEditing: _isEditing,
                        controller: _businessNameController,
                        canEdit: true,
                      ),
                      _buildDivider(isDark),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: user.email,
                        isEditing: false,
                        canEdit: false,
                        lockIcon: true,
                      ),
                      _buildDivider(isDark),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: phoneEmpty ? 'Not added yet' : user.phoneNumber,
                        isEditing: _isEditing && phoneEmpty,
                        controller: _phoneController,
                        canEdit: phoneEmpty,
                        lockIcon: !phoneEmpty,
                        emptyHighlight: phoneEmpty,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section: Account Details
                  _buildSectionHeader(theme, 'Account Details', Icons.info_rounded),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    theme: theme,
                    isDark: isDark,
                    children: [
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.verified_user_rounded,
                        label: 'Status',
                        value: user.status.label,
                        isEditing: false,
                        canEdit: false,
                        statusColor: user.status.label == 'Active'
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF59E0B),
                      ),
                      _buildDivider(isDark),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.calendar_month_rounded,
                        label: 'Joined',
                        value: _formatDate(user.createdAt),
                        isEditing: false,
                        canEdit: false,
                      ),
                      _buildDivider(isDark),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.router_rounded,
                        label: 'WhatsApp',
                        value: user.whatsappConnected ? 'Connected' : 'Not Connected',
                        isEditing: false,
                        canEdit: false,
                        statusColor: user.whatsappConnected
                            ? const Color(0xFF25D366)
                            : Colors.red.shade400,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section: Quick Links
                  _buildSectionHeader(theme, 'Quick Links', Icons.link_rounded),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    subtitle: 'App preferences & configuration',
                    color: const Color(0xFF6366F1),
                    onTap: () => context.pushNamed(RouteNames.settings),
                  ),
                  const SizedBox(height: 8),
                  _buildActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.support_agent_rounded,
                    label: 'Support',
                    subtitle: 'Get help & contact us',
                    color: const Color(0xFF0891B2),
                    onTap: () => context.pushNamed(RouteNames.support),
                  ),
                  const SizedBox(height: 8),
                  _buildActionTile(
                    theme: theme,
                    isDark: isDark,
                    icon: Icons.business_rounded,
                    label: 'Business Profile',
                    subtitle: 'Edit WhatsApp business details',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.pushNamed(RouteNames.businessProfile),
                  ),



                  const SizedBox(height: 24),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withAlpha(40)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final confirmed = await WbDialog.showConfirm(
                            context,
                            title: 'Logout',
                            message: 'Are you sure you want to logout?',
                            confirmText: 'Logout',
                            isDanger: true,
                          );
                          if (confirmed) {
                            ref.read(authNotifierProvider.notifier).logout();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPER BUILDERS ============

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required bool canEdit,
    TextEditingController? controller,
    bool lockIcon = false,
    bool emptyHighlight = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (lockIcon) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(120)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (isEditing && controller != null)
                  TextField(
                    controller: controller,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary.withAlpha(80)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  )
                else if (statusColor != null)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (emptyHighlight)
                  Row(
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFF59E0B),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 15 : 5),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withAlpha(30), color.withAlpha(15)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
