import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';

/// 📊 ANALYTICS SCREEN — Monthly WhatsApp Insights
/// Shows message usage, conversation categories, free/paid breakdown, and billing
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedRange = '30d';

  @override
  void initState() {
    super.initState();
  }

  Map<String, int> _getDateRange(String range) {
    final now = DateTime.now();
    final end = now.millisecondsSinceEpoch ~/ 1000;
    int start;

    switch (range) {
      case '7d':
        start = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
        break;
      case '30d':
        start = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
        break;
      case 'prev_month':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        start = prevMonth.millisecondsSinceEpoch ~/ 1000;
        final endOfPrev = DateTime(now.year, now.month, 0, 23, 59, 59);
        return {'start': start, 'end': endOfPrev.millisecondsSinceEpoch ~/ 1000};
      default:
        start = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
    }

    return {'start': start, 'end': end};
  }

  void _changeRange(String range) {
    setState(() {
      _selectedRange = range;
      _getDateRange(range); // update range
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(whatsappAnalyticsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = ref.watch(whatsappAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Insights'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date range filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: AppDimens.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'Last 7 days', value: '7d', selected: _selectedRange, onTap: _changeRange),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Last 30 days', value: '30d', selected: _selectedRange, onTap: _changeRange),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'This month', value: 'month', selected: _selectedRange, onTap: _changeRange),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Last month', value: 'prev_month', selected: _selectedRange, onTap: _changeRange),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: analytics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Text('Failed to load analytics\n$e', textAlign: TextAlign.center),
                ),
              ),
              data: (data) {
                if (data.isEmpty) {
                  return const Center(
                    child: Text('No analytics data available.\nMake sure your business account is configured.', textAlign: TextAlign.center),
                  );
                }

                final messages = data['messages'] as Map<String, dynamic>? ?? {};
                final conversations = data['conversations'] as Map<String, dynamic>? ?? {};
                final billing = data['billing'] as Map<String, dynamic>? ?? {};
                final categories = conversations['categories'] as Map<String, dynamic>? ?? {};

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                  padding: const EdgeInsets.all(AppDimens.md),
                  children: [
                    // ===== ALL MESSAGES =====
                    _SectionCard(
                      title: 'All Messages',
                      icon: Icons.message_rounded,
                      iconColor: AppColors.primary,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(
                            label: 'Sent',
                            value: _formatNum(messages['sent'] ?? 0),
                            color: AppColors.primary,
                          ),
                          _StatColumn(
                            label: 'Delivered',
                            value: _formatNum(messages['delivered'] ?? 0),
                            color: const Color(0xFF25D366),
                          ),
                          _StatColumn(
                            label: 'Received',
                            value: _formatNum(messages['received'] ?? 0),
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.md),

                    // ===== CONVERSATIONS BY CATEGORY =====
                    _SectionCard(
                      title: 'Conversations by Category',
                      icon: Icons.category_rounded,
                      iconColor: Colors.deepPurple,
                      child: Column(
                        children: [
                          // Column headers
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('Category', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10))),
                                Expanded(flex: 2, child: Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10), textAlign: TextAlign.center)),
                                Expanded(flex: 2, child: Text('Free / Paid', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10), textAlign: TextAlign.end)),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          _CategoryRow(theme: theme, label: 'Marketing', data: categories['MARKETING']),
                          const Divider(height: 1),
                          _CategoryRow(theme: theme, label: 'Utility', data: categories['UTILITY']),
                          const Divider(height: 1),
                          _CategoryRow(theme: theme, label: 'Authentication', data: categories['AUTHENTICATION']),
                          const Divider(height: 1),
                          _CategoryRow(theme: theme, label: 'Service', data: categories['SERVICE']),
                          const Divider(height: 1),
                          _CategoryRow(theme: theme, label: 'Referral', data: categories['REFERRAL_CONVERSION']),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.md),

                    // ===== FREE VS PAID =====
                    _SectionCard(
                      title: 'Free vs Paid Conversations',
                      icon: Icons.monetization_on_rounded,
                      iconColor: const Color(0xFFFFA726),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FreePaidCard(
                              theme: theme,
                              label: 'Free',
                              count: (conversations['total_free'] as num?)?.toInt() ?? 0,
                              total: (conversations['total'] as num?)?.toInt().clamp(1, 999999999) ?? 1,
                              color: const Color(0xFF25D366),
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: AppDimens.sm),
                          Expanded(
                            child: _FreePaidCard(
                              theme: theme,
                              label: 'Paid',
                              count: (conversations['total_paid'] as num?)?.toInt() ?? 0,
                              total: (conversations['total'] as num?)?.toInt().clamp(1, 999999999) ?? 1,
                              color: Colors.orange,
                              icon: Icons.payment_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.md),

                    // ===== BILLING / COST BREAKDOWN =====
                    _SectionCard(
                      title: 'Approximate Charges',
                      icon: Icons.receipt_long_rounded,
                      iconColor: Colors.red,
                      child: Column(
                        children: [
                          // Total cost
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppDimens.md),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary.withAlpha(20), AppColors.primary.withAlpha(5)],
                              ),
                              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Total Estimated',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_currencySymbol(billing['currency'])}${(billing['total_cost'] ?? 0.0).toStringAsFixed(2)}',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '${billing['currency'] ?? 'USD'} • ${billing['paid_conversations'] ?? 0} paid conversations',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimens.sm),

                          // Per-category cost
                          ..._buildCostRows(theme, billing['cost_breakdown'] as Map<String, dynamic>? ?? {}, billing['currency']),

                          const SizedBox(height: AppDimens.sm),
                          Text(
                            '* Approximate rates based on standard Meta pricing. Actual charges may vary.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimens.xl),
                  ],
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(dynamic n) {
    final num val = n is num ? n : 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  String _currencySymbol(dynamic currencyCode) {
    switch ((currencyCode ?? 'USD').toString().toUpperCase()) {
      case 'INR': return '₹';
      case 'USD': return '\$';
      case 'PKR': return 'Rs. ';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'AED': return 'AED ';
      case 'SAR': return 'SAR ';
      default: return '${currencyCode ?? 'USD'} ';
    }
  }

  List<Widget> _buildCostRows(ThemeData theme, Map<String, dynamic> costBreakdown, [dynamic currency]) {
    final labels = {
      'MARKETING': 'Marketing',
      'UTILITY': 'Utility',
      'AUTHENTICATION': 'Authentication',
      'SERVICE': 'Service',
      'REFERRAL_CONVERSION': 'Referral',
    };

    return labels.entries.map((entry) {
      final catData = costBreakdown[entry.key] as Map<String, dynamic>? ?? {};
      final cost = (catData['cost'] ?? 0.0);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${_currencySymbol(currency)}${cost is num ? cost.toStringAsFixed(2) : cost}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ============ REUSABLE WIDGETS ============

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final dynamic data;

  const _CategoryRow({required this.theme, required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    final catData = data as Map<String, dynamic>? ?? {};
    final total = (catData['total'] as num?)?.toInt() ?? 0;
    final free = (catData['free'] as num?)?.toInt() ?? 0;
    final paid = (catData['paid'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$total total',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$free',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF25D366),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(' / ', style: theme.textTheme.bodySmall),
                Text(
                  '$paid',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
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
}

class _FreePaidCard extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _FreePaidCard({
    required this.theme,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            '$label ($pct%)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
