import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../providers/calling/webrtc_provider.dart';

/// Call Log stream provider
final callLogsProvider = StreamProvider.family<List<CallLog>, String>((ref, userId) {
  return CallRepository().getCallLogs(userId);
});

/// 📞 CALL HISTORY SCREEN — Premium design
class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  String _filter = 'all'; // all, missed, incoming, outgoing

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login first')),
      );
    }

    final theme = Theme.of(context);
    final callLogsAsync = ref.watch(callLogsProvider(user.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Call History', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.xs),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', isSelected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Missed', isSelected: _filter == 'missed', onTap: () => setState(() => _filter = 'missed'), color: Colors.red),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Incoming', isSelected: _filter == 'incoming', onTap: () => setState(() => _filter = 'incoming'), color: Colors.green),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Outgoing', isSelected: _filter == 'outgoing', onTap: () => setState(() => _filter = 'outgoing'), color: Colors.blue),
                ],
              ),
            ),
          ),
          // Call list
          Expanded(
            child: callLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (calls) {
                // Filter out permission_request type
                var filtered = calls.where((c) => c.type != 'permission_request').toList();

                if (_filter == 'missed') {
                  filtered = filtered.where((c) => c.isMissed).toList();
                } else if (_filter == 'incoming') {
                  filtered = filtered.where((c) => c.isIncoming).toList();
                } else if (_filter == 'outgoing') {
                  filtered = filtered.where((c) => c.isOutgoing).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_missed_rounded, size: 64, color: theme.colorScheme.onSurface.withAlpha(30)),
                        const SizedBox(height: AppDimens.md),
                        Text(
                          _filter == 'all' ? 'No calls yet' : 'No $_filter calls',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppDimens.xs),
                        Text(
                          'When someone calls you on WhatsApp,\nit will appear here',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = <String, List<CallLog>>{};
                for (final call in filtered) {
                  final dateKey = _dateLabel(call.createdAt);
                  grouped.putIfAbsent(dateKey, () => []);
                  grouped[dateKey]!.add(call);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateLabel = grouped.keys.elementAt(index);
                    final dateCalls = grouped[dateLabel]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppDimens.md, bottom: AppDimens.xs),
                          child: Text(
                            dateLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...dateCalls.map((call) => _CallTile(
                              call: call,
                              userId: user.id,
                              ownerId: user.dataOwner ?? user.id,
                            )),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDay = DateTime(date.year, date.month, date.day);

    if (callDay == today) return 'Today';
    if (callDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }
}

// ============ CALL TILE ============
class _CallTile extends StatelessWidget {
  final CallLog call;
  final String userId;
  final String ownerId;

  const _CallTile({
    required this.call,
    required this.userId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissed = call.isMissed;
    final isIncoming = call.isIncoming;

    final iconData = isMissed
        ? Icons.phone_missed_rounded
        : isIncoming
            ? Icons.phone_callback_rounded
            : Icons.phone_forwarded_rounded;

    final iconColor = isMissed
        ? Colors.red
        : isIncoming
            ? Colors.green
            : Colors.blue;

    final statusText = isMissed
        ? 'Missed'
        : call.status == 'connected' || call.status == 'ended'
            ? call.durationFormatted.isNotEmpty ? call.durationFormatted : 'Connected'
            : call.status == 'rejected'
                ? 'Declined'
                : call.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          call.contactName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isMissed ? Colors.red : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded,
              size: 14,
              color: iconColor.withAlpha(180),
            ),
            const SizedBox(width: 4),
            Text(
              '$statusText · ${DateFormat('h:mm a').format(call.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // FIX: Implement callback button — was empty TODO before
        trailing: IconButton(
          icon: Icon(Icons.phone_rounded, color: AppColors.primary, size: 22),
          tooltip: 'Call back',
          onPressed: () => _callBack(context),
        ),
      ),
    );
  }

  // FIX: Real call-back implementation
  void _callBack(BuildContext context) async {
    if (call.contactPhone.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final callRepo = CallRepository();

    // Check permission before calling
    final permResult = await callRepo.checkCallPermission(
      userId: userId,
      contactPhone: call.contactPhone,
    );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (permResult['canCall'] == true) {
      // Init WebRTC, generate SDP offer, then call API
      WebRTCService? webrtc;
      String? sdpOffer;
      try {
        webrtc = WebRTCService();
        await webrtc.initialize();
        sdpOffer = await webrtc.createOffer();
        if (context.mounted) {
          ProviderScope.containerOf(context)
              .read(activeWebRTCProvider.notifier)
              .state = webrtc;
        }
      } catch (e) {
        debugPrint('[CALLHISTORY] WebRTC init failed (non-fatal): $e');
        webrtc?.dispose();
        webrtc = null;
      }

      final result = await callRepo.initiateCall(
        userId: userId,
        contactPhone: call.contactPhone,
        contactName: call.contactName,
        sdpOffer: sdpOffer,
      );

      if (!context.mounted) return;

      if (result['success'] == true) {
        final sdpAnswer = (result['data'] as Map<String, dynamic>?)
            ?['session']?['sdp'] as String?;
        context.pushNamed('in-call', extra: {
          'callId': result['callId'] ?? '',
          'contactName': call.contactName,
          'contactPhone': call.contactPhone,
          'isIncoming': false,
          'ownerId': result['ownerId'] ?? ownerId,
          'sdpAnswer': sdpAnswer,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // No permission — show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot call: ${permResult['reason'] ?? 'Permission required'}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ============ FILTER CHIP ============
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
