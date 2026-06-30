import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'force_update_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/router/route_names.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/notification/notification_listener_provider.dart';

/// 🎯 MAIN SHELL - Bottom Navigation (Role-Based) + Force Update Check
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  String _currentVersion = '99.99.99'; // Safe default — never triggers force update before load
  bool _versionLoaded = false; // Don't check force update until PackageInfo resolves

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _currentVersion = info.version;
          _versionLoaded = true;
        });
      }
    });
  }

  // Compare semantic versions: returns true if current < minimum
  bool _isVersionOlder(String current, String minimum) {
    final cParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final mParts = minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final m = i < mParts.length ? mParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final theme = Theme.of(context);

    // 🔔 Activate notification listener — active on ALL screens
    ref.watch(notificationListenerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Exit App?'),
                content: const Text('Do you really want to exit Wabees?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Exit', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('config').doc('app_version').snapshots(),
        builder: (context, versionSnap) {
          // Check force update — only after PackageInfo has loaded actual version
          if (_versionLoaded && versionSnap.hasData && versionSnap.data!.exists) {
            final vData = versionSnap.data!.data() as Map<String, dynamic>?;
            if (vData != null) {
              final minVersion = vData['minVersion'] as String? ?? '';
              final downloadUrl = vData['downloadUrl'] as String? ?? 'https://wabees.live';
              if (minVersion.isNotEmpty && _isVersionOlder(_currentVersion, minVersion)) {
                return ForceUpdateScreen(downloadUrl: downloadUrl, minVersion: minVersion);
              }
            }
          }

          return Scaffold(
            body: widget.child,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                height: AppDimens.bottomNavBarHeight,
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  _navigateToIndex(context, index, isAdmin);
                },
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: AppColors.primary.withAlpha(30),
                destinations: isAdmin ? _adminDestinations() : _userDestinations(),
              ),
            ),
          );
        },
      ),
    );
  }

  List<NavigationDestination> _userDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.message_outlined),
        selectedIcon: Icon(Icons.message),
        label: 'Messages',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: 'Contacts',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outlined),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  List<NavigationDestination> _adminDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: 'Users',
      ),
      NavigationDestination(
        icon: Icon(Icons.card_membership_outlined),
        selectedIcon: Icon(Icons.card_membership),
        label: 'Plans',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outlined),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  void _navigateToIndex(BuildContext context, int index, bool isAdmin) {
    if (isAdmin) {
      switch (index) {
        case 0:
          context.goNamed(RouteNames.dashboard);
        case 1:
          context.goNamed(RouteNames.adminUsers);
        case 2:
          context.goNamed('admin-plans-manage');
        case 3:
          context.goNamed(RouteNames.profile);
      }
    } else {
      switch (index) {
        case 0:
          context.goNamed(RouteNames.dashboard);
        case 1:
          context.goNamed(RouteNames.messages);
        case 2:
          context.goNamed(RouteNames.contacts);
        case 3:
          context.goNamed(RouteNames.profile);
      }
    }
  }
}
