import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/display/wb_card.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';
import '../../../providers/whatsapp/whatsapp_setup_provider.dart';

/// 📱 WHATSAPP CONNECTION SCREEN
class WhatsappConnectionScreen extends ConsumerStatefulWidget {
  const WhatsappConnectionScreen({super.key});

  @override
  ConsumerState<WhatsappConnectionScreen> createState() =>
      _WhatsappConnectionScreenState();
}

class _WhatsappConnectionScreenState
    extends ConsumerState<WhatsappConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneIdController = TextEditingController();
  final _tokenController = TextEditingController();
  final _testNumberController = TextEditingController();
  final _wabaIdController = TextEditingController();

  @override
  void dispose() {
    _phoneIdController.dispose();
    _tokenController.dispose();
    _testNumberController.dispose();
    _wabaIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(whatsappConfigProvider);
    final connectionState = ref.watch(whatsappConnectionProvider);
    final theme = Theme.of(context);

    // Listen for success/error messages
    ref.listen(whatsappConnectionProvider, (prev, next) {
      if (next.success != null) {
        WbSnackbar.showSuccess(context, next.success!);
        ref.read(whatsappConnectionProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        WbSnackbar.showError(context, next.error!);
        ref.read(whatsappConnectionProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Connection'),
      ),
      body: configAsync.when(
        loading: () => const WbLoading(message: 'Loading configuration...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (config) {
          return SingleChildScrollView(
            padding: AppDimens.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ============ STATUS CARD ============
                WbCard(
                  padding: AppDimens.screenPadding,
                  child: Column(
                    children: [
                      Icon(
                        config.isConnected
                            ? Icons.check_circle
                            : Icons.link_off,
                        size: 48,
                        color: config.isConnected
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        config.isConnected ? 'Connected' : 'Not Connected',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: config.isConnected
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      if (config.displayPhoneNumber != null) ...[
                        const SizedBox(height: AppDimens.xxs),
                        Text(
                          config.displayPhoneNumber!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (config.qualityRating != null) ...[
                        const SizedBox(height: AppDimens.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.sm,
                            vertical: AppDimens.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: _getQualityColor(config.qualityRating!)
                                .withAlpha(25),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusCircle),
                          ),
                          child: Text(
                            'Quality: ${config.qualityRating}',
                            style: TextStyle(
                              color:
                                  _getQualityColor(config.qualityRating!),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.xl),

                if (config.isConnected) ...[
                  // ============ CONNECTED VIEW ============
                  _buildConnectedView(config, connectionState, theme),
                ] else ...[
                  // ============ SETUP FORM ============
                  _buildSetupForm(connectionState, theme),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectedView(
    dynamic config,
    WhatsappConnectionState connectionState,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection Details
        Text(
          'Connection Details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimens.sm),

        WbCard(
          child: Column(
            children: [
              _DetailRow(
                label: 'Phone Number ID',
                value: _maskValue(config.phoneNumberId),
                onCopy: () => _copyToClipboard(config.phoneNumberId),
              ),
              const Divider(),
              _DetailRow(
                label: 'Business Account ID',
                value: config.businessAccountId.isEmpty
                    ? '⚠ Not set (needed for templates)'
                    : _maskValue(config.businessAccountId),
                onCopy: config.businessAccountId.isNotEmpty
                    ? () => _copyToClipboard(config.businessAccountId)
                    : null,
              ),
              const Divider(),
              _DetailRow(
                label: 'Connected Since',
                value: config.connectedAt != null
                    ? '${config.connectedAt.day}/${config.connectedAt.month}/${config.connectedAt.year}'
                    : 'Unknown',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.md),

        // Update WABA ID section
        WbCard(
          padding: AppDimens.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Account ID (WABA ID)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Required for templates. Go to business.facebook.com → Settings → Accounts → WhatsApp accounts → select your account → ID shown at top.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              WbTextField(
                label: 'WABA ID',
                hint: 'e.g. 123456789012345',
                controller: _wabaIdController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.business),
              ),
              const SizedBox(height: AppDimens.sm),
              WbButton(
                text: 'Update WABA ID',
                onPressed: () async {
                  final wabaId = _wabaIdController.text.trim();
                  if (wabaId.isEmpty) {
                    WbSnackbar.showWarning(context, 'Enter your WABA ID');
                    return;
                  }
                  try {
                    final repo = ref.read(whatsappRepositoryProvider);
                    final userId = ref.read(userIdProvider);
                    if (userId == null) return;
                    await repo.saveConfig(userId, config.copyWith(
                      businessAccountId: wabaId,
                    ));
                    if (mounted) {
                      ref.invalidate(whatsappConfigProvider);
                      WbSnackbar.showSuccess(context, 'WABA ID updated! Templates will now sync.');
                    }
                  } catch (e) {
                    if (mounted) {
                      WbSnackbar.showError(context, 'Failed: $e');
                    }
                  }
                },
                variant: WbButtonVariant.secondary,
                icon: Icons.save,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimens.xl),

        // Test Connection
        Text(
          'Test Connection',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimens.sm),

        WbTextField(
          label: 'Phone Number',
          hint: '+923001234567',
          controller: _testNumberController,
          keyboardType: TextInputType.phone,
          isRequired: false,
          prefixIcon: const Icon(Icons.phone),
        ),
        const SizedBox(height: AppDimens.md),

        WbButton(
          text: 'Send Test Message',
          onPressed: () {
            if (_testNumberController.text.trim().isEmpty) {
              WbSnackbar.showWarning(context, 'Enter a phone number');
              return;
            }
            ref.read(whatsappConnectionProvider.notifier).sendTestMessage(
              _testNumberController.text.trim(),
            );
          },
          isLoading: connectionState.isLoading,
          variant: WbButtonVariant.secondary,
          icon: Icons.send,
        ),
        const SizedBox(height: AppDimens.xxl),

        // Disconnect
        WbButton(
          text: 'Disconnect WhatsApp',
          onPressed: () async {
            final confirmed = await WbDialog.showConfirm(
              context,
              title: 'Disconnect WhatsApp',
              message:
                  'All messages and bot functionality will stop. Are you sure?',
              confirmText: 'Disconnect',
              isDanger: true,
            );
            if (confirmed) {
              ref.read(whatsappConnectionProvider.notifier).disconnect();
            }
          },
          variant: WbButtonVariant.danger,
          icon: Icons.link_off,
        ),
      ],
    );
  }

  Widget _buildSetupForm(
    WhatsappConnectionState connectionState,
    ThemeData theme,
  ) {
    final setupState = ref.watch(whatsappSetupProvider);

    // Listen for completion
    ref.listen(whatsappSetupProvider, (prev, next) {
      if (next.step == SetupStep.done && prev?.step != SetupStep.done) {
        WbSnackbar.showSuccess(context, next.statusMessage ?? 'Connected!');
        ref.invalidate(whatsappConfigProvider);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Instructions Card ──
        if (setupState.step == SetupStep.token)
          WbCard(
            padding: AppDimens.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high,
                        color: AppColors.primary, size: AppDimens.iconMd),
                    const SizedBox(width: AppDimens.xs),
                    Text(
                      'Smart Setup',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                _StepItem(
                    number: '1',
                    text: 'Go to developers.facebook.com → Your App'),
                _StepItem(
                    number: '2',
                    text: 'Generate an Access Token with WhatsApp permissions'),
                _StepItem(
                    number: '3',
                    text: 'Paste both below — WABA is auto-detected!'),
              ],
            ),
          ),
        if (setupState.step == SetupStep.token)
          const SizedBox(height: AppDimens.xl),

        // ── Token Input ──
        if (setupState.step == SetupStep.token) ...[
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WbTextField(
                  label: 'Access Token',
                  hint: 'EAAx...',
                  controller: _tokenController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.key),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Access Token is required';
                    }
                    if (value.trim().length < 20) {
                      return 'Access Token seems too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.md),
                WbTextField(
                  label: 'Phone Number ID',
                  hint: 'e.g. 123456789012345',
                  controller: _phoneIdController,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.phone_android),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone Number ID is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Invalid Phone Number ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.xl),
                WbButton(
                  text: 'Connect WhatsApp',
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    final userId = ref.read(userIdProvider);
                    if (userId == null) return;
                    ref
                        .read(whatsappSetupProvider.notifier)
                        .startSmartConnect(
                          token: _tokenController.text.trim(),
                          phoneId: _phoneIdController.text.trim(),
                          userId: userId,
                        );
                  },
                  icon: Icons.auto_fix_high,
                ),

              ],
            ),
          ),
        ],

        // ── Progress Stepper (shown during detection) ──
        if (setupState.step != SetupStep.token) ...[
          _buildProgressStepper(setupState, theme),
        ],

        // ── Error State ──
        if (setupState.step == SetupStep.error && setupState.error != null) ...[
          const SizedBox(height: AppDimens.md),
          WbCard(
            padding: AppDimens.screenPadding,
            child: Column(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 40),
                const SizedBox(height: AppDimens.sm),
                Text(
                  setupState.error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.md),
                WbButton(
                  text: 'Try Again',
                  onPressed: () =>
                      ref.read(whatsappSetupProvider.notifier).reset(),
                  variant: WbButtonVariant.secondary,
                  icon: Icons.refresh,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Progress Stepper Widget ──
  Widget _buildProgressStepper(SetupState setupState, ThemeData theme) {
    final steps = [
      _ProgressStep(
        label: 'Verify',
        icon: Icons.verified_user_rounded,
        isComplete: setupState.verifiedName != null && setupState.verifiedName!.isNotEmpty,
        isActive: setupState.step == SetupStep.connecting && setupState.wabaId == null,
        detail: setupState.verifiedName,
      ),

      _ProgressStep(
        label: 'Done',
        icon: Icons.check_circle_rounded,
        isComplete: setupState.step == SetupStep.done,
        isActive: false,
        detail: null,
      ),
    ];

    return WbCard(
      padding: AppDimens.screenPadding,
      child: Column(
        children: [
          // Step dots row
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].isComplete
                              ? AppColors.success
                              : steps[i].isActive
                                  ? AppColors.primary
                                  : theme.colorScheme.surfaceContainerHigh,
                        ),
                        child: Icon(
                          steps[i].isComplete
                              ? Icons.check
                              : steps[i].icon,
                          color: (steps[i].isComplete || steps[i].isActive)
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i].label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: steps[i].isComplete
                              ? AppColors.success
                              : steps[i].isActive
                                  ? AppColors.primary
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight: (steps[i].isComplete || steps[i].isActive)
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (steps[i].detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          steps[i].detail!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    flex: 0,
                    child: Container(
                      height: 2,
                      width: 20,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: steps[i].isComplete
                          ? AppColors.success
                          : theme.dividerColor.withAlpha(50),
                    ),
                  ),
              ],
            ],
          ),

          // Status message
          if (setupState.statusMessage != null) ...[
            const SizedBox(height: AppDimens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (setupState.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    setupState.statusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],

          // Back / Reset buttons
          if (!setupState.isLoading &&
              setupState.step != SetupStep.done &&
              setupState.step != SetupStep.error) ...[
            const SizedBox(height: AppDimens.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      ref.read(whatsappSetupProvider.notifier).goBack(),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(whatsappSetupProvider.notifier).reset(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Start Over'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  String _maskValue(String value) {
    if (value.length <= 6) return value;
    return '${value.substring(0, 4)}${'*' * (value.length - 6)}${value.substring(value.length - 2)}';
  }



  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    WbSnackbar.showInfo(context, 'Copied to clipboard');
  }

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case 'GREEN':
        return AppColors.success;
      case 'YELLOW':
        return AppColors.warning;
      case 'RED':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }
}

// ============ HELPER WIDGETS ============
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy, size: AppDimens.iconSm),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String text;

  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ PROGRESS STEP DATA ============
class _ProgressStep {
  final String label;
  final IconData icon;
  final bool isComplete;
  final bool isActive;
  final String? detail;

  const _ProgressStep({
    required this.label,
    required this.icon,
    required this.isComplete,
    required this.isActive,
    this.detail,
  });
}
