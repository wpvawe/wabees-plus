import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/services/notification_service.dart';
import '../../../providers/theme/theme_provider.dart';

/// 🔔 NOTIFICATION SETTINGS SCREEN — persists via Hive
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _boxName = 'notif_settings';

  bool _messageNotifications = true;
  bool _campaignNotifications = true;
  bool _botNotifications = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  Box? _box;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox(_boxName);
    if (!mounted) return;
    setState(() {
      _box = box;
      _messageNotifications  = box.get('messageNotifications',  defaultValue: true) as bool;
      _campaignNotifications = box.get('campaignNotifications', defaultValue: true) as bool;
      _botNotifications      = box.get('botNotifications',      defaultValue: false) as bool;
      _soundEnabled          = box.get('soundEnabled',          defaultValue: true) as bool;
      _vibrationEnabled      = box.get('vibrationEnabled',      defaultValue: true) as bool;
    });
    // Sync to live service
    _syncToService();
  }

  void _save(String key, bool value) {
    _box?.put(key, value);
    _syncToService();
  }

  void _syncToService() {
    final svc = NotificationService.instance;
    svc.messagesEnabled   = _messageNotifications;
    svc.campaignsEnabled  = _campaignNotifications;
    svc.botsEnabled       = _botNotifications;
    svc.soundEnabled      = _soundEnabled;
    svc.vibrationEnabled  = _vibrationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.md),
        children: [
          // ============ APPEARANCE ============
          Text(
            '🎨 Appearance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.settings_brightness),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (modes) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(modes.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.lg),

          // ============ NOTIFICATIONS ============
          Text(
            '🔔 Notifications',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('New Messages'),
                  subtitle: const Text('Get notified for incoming messages'),
                  value: _messageNotifications,
                  onChanged: (v) {
                    setState(() => _messageNotifications = v);
                    _save('messageNotifications', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Campaign Updates'),
                  subtitle: const Text('Campaign completion alerts'),
                  value: _campaignNotifications,
                  onChanged: (v) {
                    setState(() => _campaignNotifications = v);
                    _save('campaignNotifications', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Bot Activity'),
                  subtitle: const Text('Bot trigger notifications'),
                  value: _botNotifications,
                  onChanged: (v) {
                    setState(() => _botNotifications = v);
                    _save('botNotifications', v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.lg),

          // ============ SOUND & VIBRATION ============
          Text(
            '🔊 Sound & Vibration',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play notification sound'),
                  value: _soundEnabled,
                  onChanged: (v) {
                    setState(() => _soundEnabled = v);
                    _save('soundEnabled', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate on notifications'),
                  value: _vibrationEnabled,
                  onChanged: (v) {
                    setState(() => _vibrationEnabled = v);
                    _save('vibrationEnabled', v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
