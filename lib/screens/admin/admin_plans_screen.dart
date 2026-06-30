import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../data/models/plan/plan_model.dart';
import '../../../providers/plans/plan_provider.dart';

/// 💎 ADMIN PLAN MANAGEMENT SCREEN
class AdminPlansScreen extends ConsumerWidget {
  const AdminPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed('admin-dashboard');
            }
          },
        ),
        title: const Text('Manage Plans'),
        actions: [
          IconButton(
            onPressed: () => _showPlanForm(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Create Plan',
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const WbLoading(message: 'Loading plans...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return WbEmptyState(
              message: 'No plans created yet\nCreate your first pricing plan',
              icon: Icons.credit_card_off,
              actionText: 'Create Plan',
              onAction: () => _showPlanForm(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.md),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.sm),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: plan.isActive
                        ? Colors.green.withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    child: Icon(
                      Icons.credit_card,
                      color: plan.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (plan.isPopular) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '⭐',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${plan.formattedPrice} • ${plan.expiryLabel} • ${plan.limitLabel(plan.maxMessages)} msgs • ${plan.limitLabel(plan.maxAiMessages)} AI msgs',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: plan.isActive,
                        onChanged: plan.isWelcomePlan ? null : (value) {
                          ref
                              .read(planRepositoryProvider)
                              .togglePlanActive(plan.id, value);
                        },
                      ),
                      if (!plan.isWelcomePlan)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) {
                            if (action == 'edit') {
                              _showPlanForm(context, ref, existing: plan);
                            } else if (action == 'delete') {
                              _deletePlan(context, ref, plan);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  onTap: () => _showPlanForm(context, ref, existing: plan),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPlanForm(BuildContext context, WidgetRef ref,
      {PlanModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlanFormSheet(existing: existing),
    );
  }

  Future<void> _deletePlan(BuildContext context, WidgetRef ref, PlanModel plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Plan'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the "${plan.name}" plan?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(planRepositoryProvider).deletePlan(plan.id);
        if (context.mounted) {
          WbSnackbar.showSuccess(context, '"${plan.name}" plan deleted');
        }
      } catch (e) {
        if (context.mounted) {
          WbSnackbar.showError(context, e.toString());
        }
      }
    }
  }
}

class _PlanFormSheet extends ConsumerStatefulWidget {
  final PlanModel? existing;
  const _PlanFormSheet({this.existing});

  @override
  ConsumerState<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends ConsumerState<_PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _descC;
  late final TextEditingController _priceC;
  late final TextEditingController _messagesC;
  late final TextEditingController _contactsC;
  late final TextEditingController _campaignsC;
  late final TextEditingController _botsC;
  late final TextEditingController _templatesC;
  late final TextEditingController _aiMessagesC;
  late final TextEditingController _expiryDaysC;
  late final TextEditingController _featuresC;
  late bool _isPopular;
  late bool _hasAnalytics;
  late bool _hasPrioritySupport;
  late bool _hasApiAccess;
  late String _expiryType;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameC = TextEditingController(text: p?.name ?? '');
    _descC = TextEditingController(text: p?.description ?? '');
    _priceC = TextEditingController(
      text: p?.priceMonthly.toStringAsFixed(0) ?? '',
    );
    _messagesC = TextEditingController(
      text: '${p?.maxMessages ?? 1000}',
    );
    _contactsC = TextEditingController(
      text: '${p?.maxContacts ?? 100}',
    );
    _campaignsC = TextEditingController(
      text: '${p?.maxCampaigns ?? 5}',
    );
    _botsC = TextEditingController(
      text: '${p?.maxBots ?? 2}',
    );
    _templatesC = TextEditingController(
      text: '${p?.maxTemplates ?? 10}',
    );
    _aiMessagesC = TextEditingController(
      text: '${p?.maxAiMessages ?? 300}',
    );
    _expiryDaysC = TextEditingController(
      text: '${p?.expiryDays ?? 30}',
    );
    _featuresC = TextEditingController(
      text: p?.features.join(', ') ?? '',
    );
    _isPopular = p?.isPopular ?? false;
    _hasAnalytics = p?.hasAnalytics ?? false;
    _hasPrioritySupport = p?.hasPrioritySupport ?? false;
    _hasApiAccess = p?.hasApiAccess ?? false;
    _expiryType = p?.expiryType ?? 'monthly';
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _messagesC.dispose();
    _contactsC.dispose();
    _campaignsC.dispose();
    _botsC.dispose();
    _templatesC.dispose();
    _aiMessagesC.dispose();
    _expiryDaysC.dispose();
    _featuresC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final features = _featuresC.text
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    final plan = PlanModel(
      id: widget.existing?.id ?? '',
      name: _nameC.text.trim(),
      description: _descC.text.trim(),
      priceMonthly: double.tryParse(_priceC.text.trim()) ?? 0,
      maxMessages: int.tryParse(_messagesC.text.trim()) ?? 1000,
      maxContacts: int.tryParse(_contactsC.text.trim()) ?? 100,
      maxCampaigns: int.tryParse(_campaignsC.text.trim()) ?? 5,
      maxBots: int.tryParse(_botsC.text.trim()) ?? 2,
      maxTemplates: int.tryParse(_templatesC.text.trim()) ?? 10,
      maxAiMessages: int.tryParse(_aiMessagesC.text.trim()) ?? 300,
      expiryType: _expiryType,
      expiryDays: int.tryParse(_expiryDaysC.text.trim()) ?? 30,
      features: features,
      isPopular: _isPopular,
      hasAnalytics: _hasAnalytics,
      hasPrioritySupport: _hasPrioritySupport,
      hasApiAccess: _hasApiAccess,
      sortOrder: widget.existing?.sortOrder ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    final notifier = ref.read(planNotifierProvider.notifier);
    bool success;

    if (widget.existing != null) {
      success = await notifier.updatePlan(plan);
    } else {
      success = await notifier.createPlan(plan);
    }

    if (success && mounted) {
      WbSnackbar.showSuccess(
        context,
        widget.existing != null ? 'Plan updated' : 'Plan created',
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(planNotifierProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing != null ? 'Edit Plan' : 'Create Plan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Plan Name',
                hint: 'e.g., Starter, Pro, Enterprise',
                controller: _nameC,
              ),
              const SizedBox(height: AppDimens.sm),
              WbTextField(
                label: 'Description',
                hint: 'Plan description',
                controller: _descC,
                isRequired: false,
              ),
              const SizedBox(height: AppDimens.sm),
              WbTextField(
                label: 'Monthly Price (PKR)',
                hint: '999',
                controller: _priceC,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppDimens.sm),

              // Limits row
              Row(
                children: [
                  Expanded(
                    child: WbTextField(
                      label: 'Messages',
                      hint: '1000',
                      controller: _messagesC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: WbTextField(
                      label: 'Contacts',
                      hint: '100',
                      controller: _contactsC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),
              Row(
                children: [
                  Expanded(
                    child: WbTextField(
                      label: 'Campaigns',
                      hint: '5',
                      controller: _campaignsC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: WbTextField(
                      label: 'Bots',
                      hint: '2',
                      controller: _botsC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),

              WbTextField(
                label: 'Features',
                hint: 'Comma separated: Analytics, Priority Support',
                controller: _featuresC,
                isRequired: false,
              ),
              const SizedBox(height: AppDimens.sm),

              SwitchListTile(
                title: const Text('Popular Badge'),
                value: _isPopular,
                onChanged: (v) => setState(() => _isPopular = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('📊 Analytics Access'),
                subtitle: const Text('User can view analytics reports'),
                value: _hasAnalytics,
                onChanged: (v) => setState(() => _hasAnalytics = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('⭐ Priority Support'),
                subtitle: const Text('User gets priority support queue'),
                value: _hasPrioritySupport,
                onChanged: (v) => setState(() => _hasPrioritySupport = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('🔗 API Access'),
                subtitle: const Text('User can access Wabees API'),
                value: _hasApiAccess,
                onChanged: (v) => setState(() => _hasApiAccess = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppDimens.sm),

              // Expiry type
              DropdownButtonFormField<String>(
                initialValue: _expiryType,
                decoration: const InputDecoration(labelText: 'Expiry Type'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
                ],
                onChanged: (v) => setState(() => _expiryType = v ?? 'monthly'),
              ),
              const SizedBox(height: AppDimens.sm),

              if (_expiryType != 'lifetime')
                WbTextField(
                  label: 'Expiry Days',
                  hint: '30',
                  controller: _expiryDaysC,
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: AppDimens.sm),

              // Templates + AI Messages
              Row(
                children: [
                  Expanded(
                    child: WbTextField(
                      label: 'Templates',
                      hint: '10 (0 = unlimited)',
                      controller: _templatesC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: WbTextField(
                      label: 'AI Messages',
                      hint: '500 (0 = unlimited)',
                      controller: _aiMessagesC,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),

              Text(
                '💡 Set any limit to 0 for unlimited',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              WbButton(
                text: widget.existing != null ? 'Update Plan' : 'Create Plan',
                onPressed: _save,
                isLoading: actionState.isLoading,
                icon: Icons.save,
              ),
              const SizedBox(height: AppDimens.md),
            ],
          ),
        ),
      ),
    );
  }
}
