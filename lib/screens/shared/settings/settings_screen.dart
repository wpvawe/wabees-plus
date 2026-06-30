import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/theme/theme_provider.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';

/// ⚙️ SETTINGS SCREEN - PREMIUM REDESIGN
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';
  String? _apiKey;
  bool _apiKeyLoading = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.id).get();
    if (mounted) setState(() => _apiKey = doc.data()?['apiKey']);
  }

  Future<void> _generateApiKey() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _apiKeyLoading = true);
    final chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final key = 'wbk_${List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join()}';
    await FirebaseFirestore.instance.collection('users').doc(user.id).update({'apiKey': key});
    if (mounted) setState(() { _apiKey = key; _apiKeyLoading = false; });
  }

  void _showApiKeyDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.key_rounded, color: Color(0xFFEAB308)),
                const SizedBox(width: 8),
                Text('Developer API Key', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            if (_apiKey != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(_apiKey!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _apiKey!));
                        WbSnackbar.showSuccess(ctx, 'API Key copied!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Usage Example:', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  'POST https://api.wabees.live/api/send.php\n\nHeaders:\n  X-Api-Key: $_apiKey\n\nBody:\n{\n  "phone": "923001234567",\n  "message": "Hello!"\n}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFA6E3A1)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Regenerate Key'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _generateApiKey();
                    if (mounted) _showApiKeyDialog();
                  },
                ),
              ),
            ] else ...[
              Text('Generate an API key to send WhatsApp messages from your website.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('Generate API Key'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _generateApiKey();
                    if (mounted) _showApiKeyDialog();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.goNamed(RouteNames.dashboard),
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
        children: [
          // ============ GENERAL SECTION ============
          _SectionHeader(title: 'General Settings'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                iconColor: const Color(0xFF6366F1),
                title: 'Notifications',
                subtitle: 'Manage alerts and push messages',
                onTap: () => context.pushNamed('notification-settings'),
              ),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Dark Mode',
                subtitle: 'Customize your visual experience',
                trailing: Switch.adaptive(
                  value: isDark,
                  activeTrackColor: AppColors.primary,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                onTap: () => ref.read(themeProvider.notifier).toggleDarkMode(),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.lg),

          // ============ WHATSAPP SECTION ============
          _SectionHeader(title: 'WhatsApp Business API'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'Connection Status',
                subtitle: 'Manage WhatsApp Business API link',
                onTap: () => context.pushNamed(RouteNames.whatsappConnection),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Message Templates',
                subtitle: 'Manage and sync your templates',
                onTap: () => context.pushNamed(RouteNames.templates),
              ),
              _SettingsTile(
                icon: Icons.smart_toy_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Auto-Reply Bots',
                subtitle: 'Configure automated responses',
                onTap: () => context.pushNamed(RouteNames.bots),
              ),
              _SettingsTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFFD97706),
                title: 'Bulk Campaigns',
                subtitle: 'Manage your messaging campaigns',
                onTap: () => context.pushNamed(RouteNames.campaigns),
              ),
              _SettingsTile(
                icon: Icons.diamond_outlined,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Plan & Billing',
                subtitle: 'Manage your active subscription',
                onTap: () => context.pushNamed(RouteNames.plans),
              ),
              _SettingsTile(
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF0D9488),
                title: 'Business Profile',
                subtitle: 'Update about, description, and photo',
                onTap: () => context.pushNamed(RouteNames.businessProfile),
              ),
              _SettingsTile(
                icon: Icons.monitor_heart_outlined,
                iconColor: const Color(0xFF2563EB),
                title: 'Phone Health',
                subtitle: 'Quality rating and messaging limits',
                onTap: () {
                  final health = ref.read(phoneHealthProvider);
                  health.whenData((data) {
                    if (data.isEmpty) {
                      WbSnackbar.showInfo(context, 'Phone health data not available');
                      return;
                    }
                    final quality = data['quality_rating'] ?? 'UNKNOWN';
                    final tier = (data['messaging_limit_tier'] ?? 'UNKNOWN')
                        .toString().replaceAll('TIER_', 'Tier ').replaceAll('_', ' ');
                    final status = data['status'] ?? 'UNKNOWN';
                    final verified = data['verified_name'] ?? '-';
                    final phone = data['display_phone_number'] ?? '-';
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone Health', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _HealthRow('Quality Rating', quality.toString().toUpperCase()),
                            _HealthRow('Messaging Tier', tier),
                            _HealthRow('Status', status.toString()),
                            _HealthRow('Verified Name', verified.toString()),
                            _HealthRow('Phone Number', phone.toString()),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: AppDimens.lg),

          // ============ DEVELOPER API SECTION ============
          _SectionHeader(title: 'Developer API'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.key_rounded,
                iconColor: const Color(0xFFEAB308),
                title: 'API Key',
                subtitle: _apiKey != null ? '${_apiKey!.substring(0, 8)}...' : 'Generate to use HTTP API',
                trailing: _apiKeyLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: () => _showApiKeyDialog(),
              ),
            ],
          ),

          if (isAdmin) ...[
            const SizedBox(height: AppDimens.lg),

            // ============ ADMIN SECTION ============
            _SectionHeader(title: 'Administration'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.dashboard_rounded,
                  iconColor: const Color(0xFF4338CA),
                  title: 'Admin Console',
                  subtitle: 'Platform statistics and overview',
                  onTap: () => context.pushNamed('admin-dashboard'),
                ),
                _SettingsTile(
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF0891B2),
                  title: 'User Management',
                  subtitle: 'Control platform users and access',
                  onTap: () => context.pushNamed(RouteNames.adminUsers),
                ),
                _SettingsTile(
                  icon: Icons.credit_card_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Subscription Plans',
                  subtitle: 'Manage pricing and features',
                  onTap: () => context.pushNamed('admin-plans-manage'),
                ),
                _SettingsTile(
                  icon: Icons.support_agent_rounded,
                  iconColor: const Color(0xFFE11D48),
                  title: 'Support Inbox',
                  subtitle: 'Handle user queries and issues',
                  onTap: () => context.pushNamed('admin-support'),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimens.lg),

          // ============ ABOUT SECTION ============
          _SectionHeader(title: 'Platform Info'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.blueGrey,
                title: 'About WABEES',
                subtitle: 'Version $_appVersion (Stable)',
                onTap: () => WbSnackbar.showInfo(context, 'WABEES WhatsApp Business Platform v$_appVersion'),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: Colors.blueGrey,
                title: 'Terms of Service',
                onTap: () => launchUrl(Uri.parse('https://api.wabees.live/terms.php'), mode: LaunchMode.externalApplication),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.blueGrey,
                title: 'Privacy Policy',
                onTap: () => launchUrl(Uri.parse('https://api.wabees.live/privacy.php'), mode: LaunchMode.externalApplication),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.huge),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppDimens.sm),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final idx = entry.key;
          final widget = entry.value;
          final isLast = idx == children.length - 1;
          
          if (isLast) return widget;
          
          return Column(
            children: [
              widget,
              Divider(
                height: 1,
                indent: 56,
                endIndent: AppDimens.md,
                color: theme.colorScheme.outline.withAlpha(15),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(isDark ? 25 : 15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
      onTap: onTap,
    );
  }
}

/// Simple label + value row for Phone Health bottom sheet
class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  const _HealthRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
