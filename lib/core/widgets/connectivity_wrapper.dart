import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 🌐 CONNECTIVITY WIDGET — Shows offline banner
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  // Simple connectivity check — can be expanded with connectivity_plus later
  bool _isOnline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Periodic connectivity check every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnectivity());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    // Simple check — can be replaced with connectivity_plus package
    // For now, just trust the system
    if (!mounted) return;
    setState(() => _isOnline = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          MaterialBanner(
            content: const Text(
              'You are offline. Some features may not work.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            leading: const Icon(Icons.wifi_off, color: Colors.white),
            actions: [
              TextButton(
                onPressed: () => setState(() => _isOnline = true),
                child: const Text(
                  'DISMISS',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
