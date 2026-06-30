import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// 📊 ANALYTICS DASHBOARD — Premium business insights
class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  String _period = '7d'; // 7d, 30d, 90d
  bool _isLoading = true;

  // Stats
  int _totalSent = 0;
  int _totalReceived = 0;
  int _totalCalls = 0;
  int _missedCalls = 0;
  int _callMinutes = 0;
  int _activeConversations = 0;
  int _templatesSent = 0;
  int _unreadConversations = 0;
  Map<String, int> _dailySent = {};
  Map<String, int> _dailyReceived = {};
  Map<String, int> _messageTypes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final ownerId = user.dataOwner ?? user.id;
    final days = _period == '7d' ? 7 : _period == '30d' ? 30 : 90;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffTs = Timestamp.fromDate(cutoff);

    try {
      // Fetch messages
      final sentSnap = await FirebaseFirestore.instance
          .collection('users').doc(ownerId)
          .collection('messages')
          .where('direction', isEqualTo: 'outgoing')
          .where('createdAt', isGreaterThan: cutoffTs)
          .get();

      final recvSnap = await FirebaseFirestore.instance
          .collection('users').doc(ownerId)
          .collection('messages')
          .where('direction', isEqualTo: 'incoming')
          .where('createdAt', isGreaterThan: cutoffTs)
          .get();

      // Fetch call logs
      final callSnap = await FirebaseFirestore.instance
          .collection('users').doc(ownerId)
          .collection('call_logs')
          .where('createdAt', isGreaterThan: cutoffTs)
          .get();

      // Fetch conversations
      final convSnap = await FirebaseFirestore.instance
          .collection('users').doc(ownerId)
          .collection('conversations')
          .get();

      // Process sent messages
      final dailySent = <String, int>{};
      final dailyReceived = <String, int>{};
      final messageTypes = <String, int>{};
      int templateCount = 0;

      for (final doc in sentSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts != null) {
          final key = DateFormat('MM/dd').format(ts);
          dailySent[key] = (dailySent[key] ?? 0) + 1;
        }
        final type = data['type'] ?? 'text';
        messageTypes[type] = (messageTypes[type] ?? 0) + 1;
        if (type == 'template') templateCount++;
      }

      for (final doc in recvSnap.docs) {
        final data = doc.data();
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts != null) {
          final key = DateFormat('MM/dd').format(ts);
          dailyReceived[key] = (dailyReceived[key] ?? 0) + 1;
        }
      }

      // Call stats
      int missedCalls = 0;
      int totalDuration = 0;
      for (final doc in callSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'missed' || data['status'] == 'not_answered') missedCalls++;
        totalDuration += (data['duration'] as int?) ?? 0;
      }

      // Conversation stats
      int unread = 0;
      for (final doc in convSnap.docs) {
        final count = (doc.data()['unreadCount'] as int?) ?? 0;
        if (count > 0) unread++;
      }

      if (mounted) {
        setState(() {
          _totalSent = sentSnap.docs.length;
          _totalReceived = recvSnap.docs.length;
          _totalCalls = callSnap.docs.where((d) => d.data()['type'] != 'permission_request').length;
          _missedCalls = missedCalls;
          _callMinutes = (totalDuration / 60).ceil();
          _activeConversations = convSnap.docs.length;
          _templatesSent = templateCount;
          _unreadConversations = unread;
          _dailySent = dailySent;
          _dailyReceived = dailyReceived;
          _messageTypes = messageTypes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(AppDimens.md),
                children: [
                  // Period selector
                  Row(
                    children: [
                      _PeriodChip(label: '7 Days', isSelected: _period == '7d', onTap: () { setState(() => _period = '7d'); _loadAnalytics(); }),
                      const SizedBox(width: 8),
                      _PeriodChip(label: '30 Days', isSelected: _period == '30d', onTap: () { setState(() => _period = '30d'); _loadAnalytics(); }),
                      const SizedBox(width: 8),
                      _PeriodChip(label: '90 Days', isSelected: _period == '90d', onTap: () { setState(() => _period = '90d'); _loadAnalytics(); }),
                    ],
                  ),
                  const SizedBox(height: AppDimens.lg),

                  // ============ MESSAGE STATS ============
                  Text('Messages', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                        icon: Icons.send_rounded,
                        label: 'Sent',
                        value: _totalSent.toString(),
                        color: const Color(0xFF25D366),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        icon: Icons.call_received_rounded,
                        label: 'Received',
                        value: _totalReceived.toString(),
                        color: Colors.blue,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                        icon: Icons.article_rounded,
                        label: 'Templates',
                        value: _templatesSent.toString(),
                        color: Colors.orange,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        icon: Icons.mark_email_unread_rounded,
                        label: 'Unread Chats',
                        value: _unreadConversations.toString(),
                        color: Colors.red,
                      )),
                    ],
                  ),

                  const SizedBox(height: AppDimens.xl),

                  // ============ CALL STATS ============
                  Text('Calls', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.sm),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                        icon: Icons.phone_rounded,
                        label: 'Total Calls',
                        value: _totalCalls.toString(),
                        color: const Color(0xFF128C7E),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        icon: Icons.phone_missed_rounded,
                        label: 'Missed',
                        value: _missedCalls.toString(),
                        color: Colors.red,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _StatCard(
                        icon: Icons.timer_rounded,
                        label: 'Call Minutes',
                        value: _callMinutes.toString(),
                        color: Colors.purple,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(
                        icon: Icons.people_rounded,
                        label: 'Conversations',
                        value: _activeConversations.toString(),
                        color: Colors.teal,
                      )),
                    ],
                  ),

                  const SizedBox(height: AppDimens.xl),

                  // ============ MESSAGE TREND CHART ============
                  Text('Message Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.sm),
                  _TrendChart(
                    dailySent: _dailySent,
                    dailyReceived: _dailyReceived,
                  ),

                  const SizedBox(height: AppDimens.xl),

                  // ============ MESSAGE TYPE BREAKDOWN ============
                  Text('Message Types', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.sm),
                  _MessageTypeBreakdown(types: _messageTypes),

                  const SizedBox(height: AppDimens.xl),

                  // Summary card
                  Container(
                    padding: const EdgeInsets.all(AppDimens.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF25D366).withAlpha(20),
                          const Color(0xFF128C7E).withAlpha(10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(color: const Color(0xFF25D366).withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insights_rounded, color: Color(0xFF25D366), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Activity',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${_totalSent + _totalReceived} messages · $_totalCalls calls · $_activeConversations chats',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ PERIOD CHIP ============
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ============ TREND CHART (Bar Chart) ============
class _TrendChart extends StatelessWidget {
  final Map<String, int> dailySent;
  final Map<String, int> dailyReceived;

  const _TrendChart({required this.dailySent, required this.dailyReceived});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Combine all dates
    final allDates = <String>{...dailySent.keys, ...dailyReceived.keys}.toList()..sort();
    if (allDates.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Center(
          child: Text('No data for this period', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }

    // Take last 14 dates max
    final dates = allDates.length > 14 ? allDates.sublist(allDates.length - 14) : allDates;
    final maxVal = [...dates.map((d) => dailySent[d] ?? 0), ...dates.map((d) => dailyReceived[d] ?? 0)]
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        children: [
          // Legend
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Text('Sent', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 4),
              Text('Received', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          // Bars
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dates.map((date) {
                final sent = dailySent[date] ?? 0;
                final recv = dailyReceived[date] ?? 0;
                final sentH = maxVal > 0 ? (sent / maxVal) * 100 : 0.0;
                final recvH = maxVal > 0 ? (recv / maxVal) * 100 : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                height: sentH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 1),
                            Expanded(
                              child: Container(
                                height: recvH,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date.substring(date.length - 2),
                          style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ MESSAGE TYPE BREAKDOWN ============
class _MessageTypeBreakdown extends StatelessWidget {
  final Map<String, int> types;

  const _MessageTypeBreakdown({required this.types});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (types.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Center(child: Text('No data', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
      );
    }

    final total = types.values.fold<int>(0, (a, b) => a + b);
    final colorMap = {
      'text': const Color(0xFF25D366),
      'image': Colors.blue,
      'video': Colors.purple,
      'audio': Colors.orange,
      'document': Colors.teal,
      'template': Colors.indigo,
      'reaction': Colors.pink,
      'sticker': Colors.amber,
    };

    final iconMap = {
      'text': Icons.chat_bubble_rounded,
      'image': Icons.image_rounded,
      'video': Icons.videocam_rounded,
      'audio': Icons.mic_rounded,
      'document': Icons.description_rounded,
      'template': Icons.article_rounded,
      'reaction': Icons.emoji_emotions_rounded,
      'sticker': Icons.sticky_note_2_rounded,
    };

    final sorted = types.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        children: sorted.map((entry) {
          final percent = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
          final color = colorMap[entry.key] ?? Colors.grey;
          final icon = iconMap[entry.key] ?? Icons.message_rounded;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    entry.key,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? entry.value / total : 0,
                      backgroundColor: color.withAlpha(20),
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 30,
                  child: Text(
                    '(${entry.value})',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withAlpha(100)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
