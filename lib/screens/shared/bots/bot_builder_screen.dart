import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/bot/bot_model.dart';
import '../../../data/models/bot/bot_trigger_type.dart';
import '../../../providers/bots/bot_provider.dart';

/// 🤖 BOT BUILDER SCREEN — Create / Edit Bot with WhatsApp Interactive Buttons
class BotBuilderScreen extends ConsumerStatefulWidget {
  final BotModel? existingBot;

  const BotBuilderScreen({super.key, this.existingBot});

  @override
  ConsumerState<BotBuilderScreen> createState() => _BotBuilderScreenState();
}

class _BotBuilderScreenState extends ConsumerState<BotBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _responseController;
  late final TextEditingController _keywordsController;
  late final TextEditingController _delayController;
  late final TextEditingController _footerController;
  late final TextEditingController _headerTextController;
  late BotTriggerType _triggerType;
  late bool _caseSensitive;

  // Quick Reply Buttons (max 3)
  late List<TextEditingController> _quickReplyControllers;

  // CTA Button
  bool _hasCtaButton = false;
  late CtaButtonType _ctaType;
  late final TextEditingController _ctaTitleController;
  late final TextEditingController _ctaValueController;

  // Additional responses (multi-message)
  late List<Map<String, TextEditingController>> _additionalResponses;

  bool get _isEditing => widget.existingBot != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBot;
    _nameController = TextEditingController(text: b?.name ?? '');
    _descController = TextEditingController(text: b?.description ?? '');
    _responseController = TextEditingController(text: b?.responseText ?? '');
    _keywordsController = TextEditingController(
      text: b?.triggerKeywords.join(', ') ?? '',
    );
    _delayController = TextEditingController(
      text: b?.delaySeconds.toString() ?? '0',
    );
    _footerController = TextEditingController(text: b?.footerText ?? '');
    _headerTextController = TextEditingController(text: b?.headerText ?? '');
    _triggerType = b?.triggerType ?? BotTriggerType.keyword;
    _caseSensitive = b?.caseSensitive ?? false;

    // Quick Replies
    _quickReplyControllers = (b?.quickReplies ?? [])
        .map((qr) => TextEditingController(text: qr.title))
        .toList();

    // CTA Button
    _hasCtaButton = b?.ctaButton != null;
    _ctaType = b?.ctaButton?.type ?? CtaButtonType.url;
    _ctaTitleController =
        TextEditingController(text: b?.ctaButton?.title ?? '');
    _ctaValueController =
        TextEditingController(text: b?.ctaButton?.value ?? '');

    // Additional responses
    _additionalResponses = (b?.additionalResponses ?? []).map((r) => <String, TextEditingController>{
      'text': TextEditingController(text: r.responseText),
      'delay': TextEditingController(text: r.delaySeconds.toString()),
    }).toList();

    // Live preview listeners
    _responseController.addListener(_onPreviewChanged);
    _footerController.addListener(_onPreviewChanged);
    _headerTextController.addListener(_onPreviewChanged);
    _ctaTitleController.addListener(_onPreviewChanged);
    _ctaValueController.addListener(_onPreviewChanged);
  }

  void _onPreviewChanged() => setState(() {});

  @override
  void dispose() {
    _responseController.removeListener(_onPreviewChanged);
    _footerController.removeListener(_onPreviewChanged);
    _headerTextController.removeListener(_onPreviewChanged);
    _ctaTitleController.removeListener(_onPreviewChanged);
    _ctaValueController.removeListener(_onPreviewChanged);
    _nameController.dispose();
    _descController.dispose();
    _responseController.dispose();
    _keywordsController.dispose();
    _delayController.dispose();
    _footerController.dispose();
    _headerTextController.dispose();
    _ctaTitleController.dispose();
    _ctaValueController.dispose();
    for (final c in _quickReplyControllers) {
      c.dispose();
    }
    for (final m in _additionalResponses) {
      m['text']?.dispose();
      m['delay']?.dispose();
    }
    super.dispose();
  }

  void _addQuickReply() {
    if (_quickReplyControllers.length >= 3) {
      WbSnackbar.showError(context, 'Maximum 3 quick reply buttons allowed');
      return;
    }
    setState(() {
      _quickReplyControllers.add(TextEditingController());
    });
  }

  void _removeQuickReply(int index) {
    setState(() {
      _quickReplyControllers[index].dispose();
      _quickReplyControllers.removeAt(index);
    });
  }

  void _addAdditionalResponse() {
    setState(() {
      _additionalResponses.add({
        'text': TextEditingController(),
        'delay': TextEditingController(text: '1'),
      });
    });
  }

  void _removeAdditionalResponse(int index) {
    setState(() {
      _additionalResponses[index]['text']?.dispose();
      _additionalResponses[index]['delay']?.dispose();
      _additionalResponses.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final needsKeywords = _triggerType != BotTriggerType.allMessages &&
        _triggerType != BotTriggerType.welcomeMessage;
    final keywords = needsKeywords
        ? _keywordsController.text
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList()
        : <String>[];

    // Build quick replies
    final quickReplies = <BotQuickReply>[];
    for (int i = 0; i < _quickReplyControllers.length; i++) {
      var title = _quickReplyControllers[i].text.trim();
      if (title.isNotEmpty) {
        // WhatsApp quick reply button limit ~20 characters (grapheme-safe)
        if (title.characters.length > 20) {
          title = title.characters.take(20).toString();
        }
        quickReplies.add(BotQuickReply(
          id: 'qr_${i + 1}',
          title: title,
        ));
      }
    }

    // Build CTA button
    BotCtaButton? ctaButton;
    if (_hasCtaButton &&
        _ctaTitleController.text.trim().isNotEmpty &&
        _ctaValueController.text.trim().isNotEmpty) {
      // Enforce ~20 char button title for CTA as well
      var ctaTitle = _ctaTitleController.text.trim();
      if (ctaTitle.characters.length > 20) {
        ctaTitle = ctaTitle.characters.take(20).toString();
      }
      ctaButton = BotCtaButton(
        type: _ctaType,
        title: ctaTitle,
        value: _ctaValueController.text.trim(),
      );
    }

    final bot = BotModel(
      id: widget.existingBot?.id ?? '',
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      isActive: widget.existingBot?.isActive ?? true,
      triggerType: _triggerType,
      triggerKeywords: keywords,
      caseSensitive: _caseSensitive,
      responseText: _responseController.text.trim(),
      headerText: _headerTextController.text.trim().isEmpty
          ? null
          : _headerTextController.text.trim(),
      delaySeconds: int.tryParse(_delayController.text.trim()) ?? 0,
      quickReplies: quickReplies,
      ctaButton: ctaButton,
      footerText: _footerController.text.trim().isEmpty
          ? null
          : _footerController.text.trim(),
      totalTriggered: widget.existingBot?.totalTriggered ?? 0,
      createdAt: widget.existingBot?.createdAt ?? DateTime.now(),
      additionalResponses: _additionalResponses.map((ctrl) {
        final text = ctrl['text']!.text.trim();
        if (text.isEmpty) return null;
        return BotAdditionalResponse(
          responseText: text,
          delaySeconds: int.tryParse(ctrl['delay']!.text) ?? 1,
        );
      }).whereType<BotAdditionalResponse>().toList(),
    );

    bool success;
    if (_isEditing) {
      success = await ref.read(botNotifierProvider.notifier).update(bot);
    } else {
      success = await ref.read(botNotifierProvider.notifier).create(bot);
    }

    if (success && mounted) {
      WbSnackbar.showSuccess(
        context,
        _isEditing ? 'Bot updated' : 'Bot created',
      );
      context.pop();
    } else if (mounted) {
      WbSnackbar.showError(
        context,
        ref.read(botNotifierProvider).error ?? 'Failed',
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Bot',
      message: 'Are you sure you want to delete this bot?',
      isDanger: true,
    );

    if (!confirmed) return;

    final success = await ref
        .read(botNotifierProvider.notifier)
        .delete(widget.existingBot!.id);

    if (success && mounted) {
      WbSnackbar.showSuccess(context, 'Bot deleted');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(botNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bot' : 'Create Bot'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppDimens.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.md),

              // ============ BASIC INFO ============
              _sectionTitle(theme, '🤖 Basic Info'),
              const SizedBox(height: AppDimens.sm),

              WbTextField(
                label: 'Bot Name',
                hint: 'e.g., Welcome Bot',
                controller: _nameController,
                prefixIcon: const Icon(Icons.smart_toy),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Description',
                hint: 'What does this bot do?',
                controller: _descController,
                maxLines: 2,
                isRequired: false,
                prefixIcon: const Icon(Icons.description),
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: AppDimens.xl),

              // ============ TRIGGER CONFIG ============
              _sectionTitle(theme, '⚡ Trigger Configuration'),
              const SizedBox(height: AppDimens.sm),

              DropdownButtonFormField<BotTriggerType>(
                initialValue: _triggerType,
                decoration: const InputDecoration(
                  labelText: 'Trigger Type',
                  prefixIcon: Icon(Icons.flash_on),
                ),
                items: BotTriggerType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _triggerType = value);
                },
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                _triggerType.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.md),

              if (_triggerType != BotTriggerType.allMessages &&
                  _triggerType != BotTriggerType.welcomeMessage) ...[
                WbTextField(
                  label: 'Keywords / Patterns',
                  hint: 'Comma separated: hello, hi, hey',
                  controller: _keywordsController,
                  maxLines: 2,
                  prefixIcon: const Icon(Icons.key),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.sm),

                SwitchListTile(
                  title: const Text('Case Sensitive'),
                  subtitle: const Text('Match exact letter casing'),
                  value: _caseSensitive,
                  onChanged: (value) =>
                      setState(() => _caseSensitive = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ],

              const SizedBox(height: AppDimens.xl),

              // ============ RESPONSE CONFIG ============
              _sectionTitle(theme, '💬 Auto-Reply Message'),
              const SizedBox(height: AppDimens.sm),

              WbTextField(
                label: 'Header (optional)',
                hint: 'Bold text above message body',
                controller: _headerTextController,
                isRequired: false,
                prefixIcon: const Icon(Icons.title),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Response Text',
                hint: 'The message to send automatically...',
                controller: _responseController,
                maxLines: 4,
                prefixIcon: const Icon(Icons.chat),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Footer Text (optional)',
                hint: 'Small text below message body',
                controller: _footerController,
                isRequired: false,
                prefixIcon: const Icon(Icons.text_fields),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Delay (seconds)',
                hint: '0 = instant reply',
                controller: _delayController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.timer),
                isRequired: false,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: AppDimens.xl),

              // ============ QUICK REPLY BUTTONS (max 3) ============
              _sectionTitle(theme, '⚡ Quick Reply Buttons'),
              const SizedBox(height: AppDimens.xxs),
              Text(
                'User can tap these buttons to reply (max 3, shown below the message)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              ..._quickReplyControllers.asMap().entries.map((entry) {
                final i = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: 'Button ${i + 1}',
                            hintText: 'e.g., Yes, No, More Info',
                            prefixIcon:
                                const Icon(Icons.smart_button_outlined),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.xs),
                      IconButton(
                        onPressed: () => _removeQuickReply(i),
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                );
              }),

              if (_quickReplyControllers.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addQuickReply,
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Add Quick Reply (${_quickReplyControllers.length}/3)',
                    ),
                  ),
                ),

              const SizedBox(height: AppDimens.xl),

              // ============ CTA BUTTON ============
              _sectionTitle(theme, '🔗 Call-to-Action Button'),
              const SizedBox(height: AppDimens.xxs),
              Text(
                'A button below the message for opening a URL or calling a number',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              SwitchListTile(
                title: const Text('Enable CTA Button'),
                subtitle: const Text('Add a Visit Website or Call button'),
                value: _hasCtaButton,
                onChanged: (value) =>
                    setState(() => _hasCtaButton = value),
                contentPadding: EdgeInsets.zero,
              ),

              if (_hasCtaButton) ...[
                const SizedBox(height: AppDimens.sm),
                SegmentedButton<CtaButtonType>(
                  segments: CtaButtonType.values.map((type) {
                    return ButtonSegment(
                      value: type,
                      label: Text(type.label),
                      icon: Icon(type == CtaButtonType.url
                          ? Icons.link
                          : Icons.phone),
                    );
                  }).toList(),
                  selected: {_ctaType},
                  onSelectionChanged: (selection) {
                    setState(() => _ctaType = selection.first);
                  },
                ),
                const SizedBox(height: AppDimens.md),

                WbTextField(
                  label: 'Button Title',
                  hint: _ctaType == CtaButtonType.url
                      ? 'e.g., Visit Website'
                      : 'e.g., Call Us',
                  controller: _ctaTitleController,
                  prefixIcon: const Icon(Icons.title),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppDimens.md),

                WbTextField(
                  label: _ctaType == CtaButtonType.url ? 'URL' : 'Phone Number',
                  hint: _ctaType == CtaButtonType.url
                      ? 'https://example.com'
                      : '+923001234567',
                  controller: _ctaValueController,
                  keyboardType: _ctaType == CtaButtonType.url
                      ? TextInputType.url
                      : TextInputType.phone,
                  prefixIcon: Icon(_ctaType == CtaButtonType.url
                      ? Icons.link
                      : Icons.phone),
                  textInputAction: TextInputAction.done,
                ),
              ],

              const SizedBox(height: AppDimens.xl),

              // ============ MULTI-RESPONSE ============
              _sectionTitle(theme, '📨 Additional Responses'),
              const SizedBox(height: AppDimens.xxs),
              Text(
                'Send multiple messages after the main response',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              ..._additionalResponses.asMap().entries.map((entry) {
                final i = entry.key;
                final ctrls = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppDimens.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.sm),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Response ${i + 1}',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              onPressed: () => _removeAdditionalResponse(i),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            ),
                          ],
                        ),
                        TextField(
                          controller: ctrls['text'],
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message Text',
                            hintText: 'Additional message...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: AppDimens.xs),
                        TextField(
                          controller: ctrls['delay'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Delay (seconds)',
                            hintText: '1',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addAdditionalResponse,
                  icon: const Icon(Icons.add),
                  label: Text('Add Response (${_additionalResponses.length})'),
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // ============ PREVIEW ============
              _sectionTitle(theme, '👁️ Preview'),
              const SizedBox(height: AppDimens.sm),
              _buildPreview(theme),
              const SizedBox(height: AppDimens.xl),

              WbButton(
                text: _isEditing ? 'Update Bot' : 'Create Bot',
                onPressed: _save,
                isLoading: actionState.isLoading,
                icon: Icons.save,
              ),

              const SizedBox(height: AppDimens.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// WhatsApp-style message preview
  Widget _buildPreview(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Message body
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimens.radiusMd),
                bottom: (_quickReplyControllers.isEmpty && !_hasCtaButton)
                    ? Radius.circular(AppDimens.radiusMd)
                    : Radius.zero,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_headerTextController.text.isNotEmpty) ...[
                  Text(
                    _headerTextController.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  _responseController.text.isEmpty
                      ? 'Your message here...'
                      : _responseController.text,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_footerController.text.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    _footerController.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quick Reply Buttons preview
          if (_quickReplyControllers.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimens.xs),
              child: Wrap(
                spacing: AppDimens.xs,
                runSpacing: AppDimens.xs,
                children: _quickReplyControllers.map((ctrl) {
                  final text = ctrl.text.isEmpty ? 'Button' : ctrl.text;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                      vertical: AppDimens.xs,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusCircle),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // CTA Button preview
          if (_hasCtaButton) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppDimens.radiusMd),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _ctaType == CtaButtonType.url
                        ? Icons.open_in_new
                        : Icons.phone,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: AppDimens.xs),
                  Text(
                    _ctaTitleController.text.isEmpty
                        ? (_ctaType == CtaButtonType.url
                            ? 'Visit Website'
                            : 'Call Us')
                        : _ctaTitleController.text,
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
