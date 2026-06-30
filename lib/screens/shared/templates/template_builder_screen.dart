import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/template/template_model.dart';
import '../../../providers/templates/template_provider.dart';

/// 📋 TEMPLATE BUILDER — Create / Edit Templates
class TemplateBuilderScreen extends ConsumerStatefulWidget {
  final TemplateModel? existingTemplate;

  const TemplateBuilderScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<TemplateBuilderScreen> createState() =>
      _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState
    extends ConsumerState<TemplateBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bodyController = TextEditingController();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();

  String _category = 'MARKETING';
  String _languageCode = 'en_US';

  // Variable system
  final Map<String, String> _variableSamples = {};
  final Map<String, String> _variableTypes = {};
  final Map<String, TextEditingController> _sampleControllers = {};
  List<String> _detectedVars = [];
  List<Map<String, dynamic>> _buttons = [];

  bool get isEditing => widget.existingTemplate != null;

  static const _categories = [
    {'value': 'MARKETING', 'label': 'Marketing', 'icon': Icons.campaign},
    {'value': 'UTILITY', 'label': 'Utility', 'icon': Icons.build},
    {'value': 'AUTHENTICATION', 'label': 'Authentication', 'icon': Icons.lock},
  ];

  static const _languages = [
    {'code': 'en_US', 'label': 'English (US)'},
    {'code': 'en', 'label': 'English'},
    {'code': 'ur', 'label': 'Urdu'},
    {'code': 'ar', 'label': 'Arabic'},
    {'code': 'hi', 'label': 'Hindi'},
    {'code': 'es', 'label': 'Spanish'},
    {'code': 'fr', 'label': 'French'},
    {'code': 'pt_BR', 'label': 'Portuguese (BR)'},
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final t = widget.existingTemplate!;
      _nameController.text = t.name;
      _bodyController.text = t.body;
      _headerController.text = t.header ?? '';
      _footerController.text = t.footer ?? '';
      _category = t.category.toUpperCase();
      _languageCode = t.languageCode;
      _variableSamples.addAll(t.variableSamples);
      _variableTypes.addAll(t.variableTypes);
      _buttons = List<Map<String, dynamic>>.from(t.buttons);
    }

    // Listen for live preview updates + variable detection
    _bodyController.addListener(_onTextChanged);
    _headerController.addListener(_onTextChanged);
    _footerController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final newVars = TemplateModel.extractVariables(_bodyController.text);
    // Preserve existing samples/types, remove stale ones
    _variableSamples.removeWhere((k, _) => !newVars.contains(k));
    _variableTypes.removeWhere((k, _) => !newVars.contains(k));
    // Remove stale controllers
    final staleKeys = _sampleControllers.keys.where((k) => !newVars.contains(k)).toList();
    for (final k in staleKeys) {
      _sampleControllers[k]?.dispose();
      _sampleControllers.remove(k);
    }
    for (final v in newVars) {
      _variableTypes.putIfAbsent(v, () => 'string');
      _variableSamples.putIfAbsent(v, () => '');
      _sampleControllers.putIfAbsent(v, () => TextEditingController(text: _variableSamples[v]));
    }
    setState(() => _detectedVars = newVars);
  }

  @override
  void dispose() {
    _bodyController.removeListener(_onTextChanged);
    _headerController.removeListener(_onTextChanged);
    _footerController.removeListener(_onTextChanged);
    _nameController.dispose();
    _bodyController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    for (final c in _sampleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Checks if body mixes numbered {{1}} and named {{name}} variables
  String? _validateVariableTypes(String body) {
    final numberedRegex = RegExp(r'\{\{(\d+)\}\}');
    final namedRegex = RegExp(r'\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}');
    final hasNumbered = numberedRegex.hasMatch(body);
    final hasNamed = namedRegex.hasMatch(body);
    if (hasNumbered && hasNamed) {
      return 'Cannot mix numbered ({{1}}) and named ({{name}}) variables. Use one type only.';
    }
    if (hasNumbered) {
      return 'Use named variables like {{name}} instead of numbered {{1}}. Example: {{customer_name}}';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate variable types (no mixing)
    final typeError = _validateVariableTypes(_bodyController.text.trim());
    if (typeError != null) {
      WbSnackbar.showError(context, typeError);
      return;
    }

    // Validate samples for all variables
    for (final v in _detectedVars) {
      if (_variableSamples[v] == null || _variableSamples[v]!.trim().isEmpty) {
        WbSnackbar.showWarning(
          context,
          'Please provide a sample value for {{$v}}',
        );
        return;
      }
    }

    final name = _nameController.text.trim().toLowerCase().replaceAll(' ', '_');
    final body = _bodyController.text.trim();
    final header = _headerController.text.trim();
    final footer = _footerController.text.trim();
    final variables = TemplateModel.extractVariables(body);

    final template = TemplateModel(
      id: widget.existingTemplate?.id ?? '',
      metaTemplateId: widget.existingTemplate?.metaTemplateId,
      name: name,
      category: _category.toUpperCase(),
      languageCode: _languageCode,
      body: body,
      header: header.isEmpty ? null : header,
      footer: footer.isEmpty ? null : footer,
      variables: variables,
      variableSamples: Map<String, String>.from(_variableSamples),
      variableTypes: Map<String, String>.from(_variableTypes),
      status: widget.existingTemplate?.status ?? 'PENDING',
      isSynced: widget.existingTemplate?.isSynced ?? false,
      createdAt: widget.existingTemplate?.createdAt ?? DateTime.now(),
      buttons: List<Map<String, dynamic>>.from(_buttons),
    );

    final notifier = ref.read(templateNotifierProvider.notifier);
    bool success;

    if (isEditing) {
      success = await notifier.update(template);
    } else {
      success = await notifier.create(template);
    }

    if (mounted) {
      if (success) {
        WbSnackbar.showSuccess(
          context,
          isEditing
              ? 'Template updated — status will be re-reviewed'
              : 'Template submitted to WhatsApp for approval',
        );
        Navigator.pop(context);
      } else {
        final error = ref.read(templateNotifierProvider).error;
        WbSnackbar.showError(context, error ?? 'Failed to save template');
      }
    }
  }

  // ── Add Variable Dialog ──
  void _showAddVariableDialog() {
    final nameCtrl = TextEditingController();
    String selectedType = 'string';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Variable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                keyboardType: selectedType == 'number'
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Variable Name',
                  hintText: selectedType == 'number'
                      ? 'e.g. 1, 2, 3'
                      : 'e.g. name, order_number',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Type',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeChip(
                    label: 'Text',
                    icon: Icons.text_fields,
                    isSelected: selectedType == 'string',
                    onTap: () =>
                        setDialogState(() => selectedType = 'string'),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'Number',
                    icon: Icons.pin,
                    isSelected: selectedType == 'number',
                    onTap: () =>
                        setDialogState(() => selectedType = 'number'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final varName = nameCtrl.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                if (varName.isEmpty) {
                  WbSnackbar.showWarning(context, 'Enter a variable name');
                  return;
                }
                Navigator.pop(ctx);
                _insertVariable(varName, selectedType);
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _insertVariable(String name, String type) {
    final text = _bodyController.text;
    final sel = _bodyController.selection;
    final insert = '{{$name}}';

    if (sel.isValid && sel.baseOffset >= 0) {
      final newText =
          text.replaceRange(sel.baseOffset, sel.extentOffset, insert);
      _bodyController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.baseOffset + insert.length,
        ),
      );
    } else {
      _bodyController.text = text + insert;
    }

    _variableTypes[name] = type;
    _variableSamples.putIfAbsent(name, () => '');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(templateNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'Create Template'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: () => _confirmDelete(),
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppDimens.screenPadding,
          children: [
            // ============ NAME ============
            WbTextField(
              controller: _nameController,
              label: 'Template Name',
              hint: 'e.g. order_confirmation',
              prefixIcon: const Icon(Icons.label_outline),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.contains(' ')) {
                  return 'Use underscores instead of spaces';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                  return 'Only letters, numbers, underscores';
                }
                return null;
              },
              enabled: !isEditing, // Meta doesn't allow renaming
            ),
            const SizedBox(height: AppDimens.md),

            // ============ CATEGORY ============
            Text(
              'Category',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.xs),
            Row(
              children: _categories.map((c) {
                final isSelected = _category == c['value'];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: c != _categories.last ? AppDimens.xs : 0,
                    ),
                    child: IgnorePointer(
                      ignoring: isEditing,
                      child: Opacity(
                        opacity: isEditing ? 0.5 : 1.0,
                        child: _CategoryChip(
                          label: c['label'] as String,
                          icon: c['icon'] as IconData,
                          isSelected: isSelected,
                          onTap: () => setState(() => _category = c['value'] as String),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.xs),
                child: Text(
                  'Category cannot be changed after creation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: AppDimens.md),

            // ============ LANGUAGE ============
            DropdownButtonFormField<String>(
              initialValue: _languageCode,
              decoration: InputDecoration(
                labelText: 'Language',
                prefixIcon: const Icon(Icons.language),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
              items: _languages
                  .map((l) => DropdownMenuItem(
                        value: l['code'] as String,
                        child: Text(l['label'] as String),
                      ))
                  .toList(),
              onChanged: isEditing ? null : (v) {
                if (v != null) setState(() => _languageCode = v);
              },
            ),
            const SizedBox(height: AppDimens.md),

            // ============ HEADER (optional) ============
            WbTextField(
              controller: _headerController,
              label: 'Header',
              hint: 'Short header text (optional)',
              prefixIcon: const Icon(Icons.title),
              maxLines: 1,
              isRequired: false,
            ),
            const SizedBox(height: AppDimens.md),

            // ============ BODY ============
            WbTextField(
              controller: _bodyController,
              label: 'Body',
              hint: 'Hello {{name}}, your order {{order_number}} is confirmed!',
              prefixIcon: const Icon(Icons.message),
              maxLines: 5,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Body is required';
                if (v.trim().length < 10) return 'Body too short (min 10 chars)';
                return null;
              },
            ),
            const SizedBox(height: AppDimens.xs),

            // ── Add Variable Button ──
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
                    child: Text(
                      'Use {{name}} format for dynamic variables',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddVariableDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add variable'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            // ============ VARIABLE SAMPLES ============
            if (_detectedVars.isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              _buildVariableSamples(theme),
            ],
            const SizedBox(height: AppDimens.md),

            // ============ FOOTER (optional) ============
            WbTextField(
              controller: _footerController,
              label: 'Footer',
              hint: 'Reply STOP to unsubscribe (optional)',
              prefixIcon: const Icon(Icons.short_text),
              maxLines: 1,
              isRequired: false,
            ),
            const SizedBox(height: AppDimens.lg),

            // ============ BUTTONS (optional, max 3) ============
            _buildButtonsSection(theme),
            const SizedBox(height: AppDimens.lg),

            // ============ LIVE PREVIEW ============
            _buildLivePreview(theme),
            const SizedBox(height: AppDimens.lg),

            // ============ IMPORTANT NOTE ============
            Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(15),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.info.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.cloud_upload,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editing this template will submit changes to WhatsApp for re-review. Only body, header, and footer can be changed.'
                          : 'This template will be submitted to WhatsApp for approval. Once approved, you can use it to send messages.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),

            // ============ SAVE BUTTON ============
            WbButton(
              onPressed: actionState.isLoading ? null : _save,
              text: isEditing ? 'Update & Submit for Review' : 'Create & Submit to WhatsApp',
              isLoading: actionState.isLoading,
              icon: isEditing ? Icons.save : Icons.cloud_upload,
            ),
            const SizedBox(height: AppDimens.xxl),
          ],
        ),
      ),
    );
  }
  // ── Buttons Section ──
  Widget _buildButtonsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smart_button, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Buttons',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_buttons.length < 3)
              TextButton.icon(
                onPressed: _showAddButtonDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Button'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        if (_buttons.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No buttons added. You can add up to 3 buttons (URL, Phone, Quick Reply).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        for (int i = 0; i < _buttons.length; i++)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
            ),
            child: Row(
              children: [
                Icon(
                  _buttons[i]['type'] == 'URL'
                      ? Icons.link
                      : _buttons[i]['type'] == 'PHONE_NUMBER'
                          ? Icons.phone
                          : Icons.reply,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _buttons[i]['text'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_buttons[i]['url'] != null)
                        Text(
                          _buttons[i]['url'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_buttons[i]['phone_number'] != null)
                        Text(
                          _buttons[i]['phone_number'],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _buttons[i]['type'] == 'URL'
                        ? 'URL'
                        : _buttons[i]['type'] == 'PHONE_NUMBER'
                            ? 'Phone'
                            : 'Quick Reply',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _buttons.removeAt(i)),
                  icon: Icon(Icons.close, size: 16, color: AppColors.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showAddButtonDialog() {
    final textCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String selectedType = 'QUICK_REPLY';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Button'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Text(
                'Button Type',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TypeChip(
                    label: 'Quick Reply',
                    icon: Icons.reply,
                    isSelected: selectedType == 'QUICK_REPLY',
                    onTap: () => setDialogState(() => selectedType = 'QUICK_REPLY'),
                  ),
                  _TypeChip(
                    label: 'URL',
                    icon: Icons.link,
                    isSelected: selectedType == 'URL',
                    onTap: () => setDialogState(() => selectedType = 'URL'),
                  ),
                  _TypeChip(
                    label: 'Phone',
                    icon: Icons.phone,
                    isSelected: selectedType == 'PHONE_NUMBER',
                    onTap: () => setDialogState(() => selectedType = 'PHONE_NUMBER'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Button text
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  labelText: 'Button Text',
                  hintText: selectedType == 'URL'
                      ? 'e.g. Visit Website'
                      : selectedType == 'PHONE_NUMBER'
                          ? 'e.g. Call Us'
                          : 'e.g. Yes, I\'m interested',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              // Value field for URL and Phone
              if (selectedType == 'URL' || selectedType == 'PHONE_NUMBER') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: selectedType == 'URL' ? 'URL' : 'Phone Number',
                    hintText: selectedType == 'URL'
                        ? 'https://example.com'
                        : '+923001234567',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      selectedType == 'URL' ? Icons.link : Icons.phone,
                    ),
                  ),
                  keyboardType: selectedType == 'PHONE_NUMBER'
                      ? TextInputType.phone
                      : TextInputType.url,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textCtrl.text.trim();
                if (text.isEmpty) {
                  WbSnackbar.showWarning(context, 'Button text is required');
                  return;
                }
                if (selectedType == 'URL' && valueCtrl.text.trim().isEmpty) {
                  WbSnackbar.showWarning(context, 'URL is required');
                  return;
                }
                if (selectedType == 'PHONE_NUMBER' && valueCtrl.text.trim().isEmpty) {
                  WbSnackbar.showWarning(context, 'Phone number is required');
                  return;
                }

                final button = <String, dynamic>{
                  'type': selectedType,
                  'text': text,
                };
                if (selectedType == 'URL') {
                  button['url'] = valueCtrl.text.trim();
                } else if (selectedType == 'PHONE_NUMBER') {
                  button['phone_number'] = valueCtrl.text.trim();
                }

                Navigator.pop(ctx);
                setState(() => _buttons.add(button));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Variable Samples Section ──
  Widget _buildVariableSamples(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Variable Samples',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Provide sample values for Meta review.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.md),

          // Variable rows — each as its own Column for clean alignment
          for (int i = 0; i < _detectedVars.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildVariableRow(theme, _detectedVars[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildVariableRow(ThemeData theme, String varName) {
    final isNumber = _variableTypes[varName] == 'number';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row: chip + type badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Text(
                '{{$varName}}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _variableTypes[varName] = isNumber ? 'string' : 'number';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isNumber
                      ? Colors.orange.withAlpha(20)
                      : Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isNumber
                        ? Colors.orange.withAlpha(60)
                        : Colors.blue.withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNumber ? Icons.pin : Icons.text_fields,
                      size: 12,
                      color: isNumber ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNumber ? 'Number' : 'Text',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isNumber ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Sample value input — full width
        SizedBox(
          height: 40,
          child: TextField(
            controller: _sampleControllers[varName],
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: isNumber ? 'e.g. 14865757' : 'e.g. Asad',
              prefixText: 'Sample: ',
              prefixStyle: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              _variableSamples[varName] = val;
              setState(() {}); // update preview
            },
          ),
        ),
      ],
    );
  }

  // ── Live Preview (WhatsApp bubble) ──
  Widget _buildLivePreview(ThemeData theme) {
    final bodyText = _bodyController.text;
    if (bodyText.isEmpty) return const SizedBox.shrink();

    // Replace variables with sample values or highlighted placeholders
    final previewBody = bodyText.replaceAllMapped(
      RegExp(r'\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}'),
      (m) {
        final name = m.group(1)!;
        final sample = _variableSamples[name];
        if (sample != null && sample.isNotEmpty) return sample;
        return '[$name]';
      },
    );

    final headerText = _headerController.text;
    final footerText = _footerController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_android, size: 16,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Template Preview',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.md),
          decoration: BoxDecoration(
            color: const Color(0xFFDCF8C6),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    headerText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              _buildRichPreviewBody(previewBody),
              if (footerText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    footerText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withAlpha(130),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              // Preview buttons
              if (_buttons.isNotEmpty) ...[
                const Divider(height: 16, color: Colors.black12),
                for (final btn in _buttons)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          btn['type'] == 'URL'
                              ? Icons.link
                              : btn['type'] == 'PHONE_NUMBER'
                                  ? Icons.phone
                                  : Icons.reply,
                          size: 14,
                          color: const Color(0xFF34B7F1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          btn['text'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF34B7F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build body with sample values highlighted
  Widget _buildRichPreviewBody(String text) {
    final regex = RegExp(r'\[([a-zA-Z_][a-zA-Z0-9_]*)\]');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
        ));
      }
      // Unfilled placeholder — highlight it
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: 14,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          backgroundColor: AppColors.primary.withAlpha(20),
          height: 1.4,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _confirmDelete() async {
    final tpl = widget.existingTemplate!;
    final message = tpl.isSynced
        ? 'This will delete "${tpl.name}" from WhatsApp Business Suite AND this app. This cannot be undone.'
        : 'Are you sure you want to delete "${tpl.name}"?';

    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Template',
      message: message,
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      final success = await ref
          .read(templateNotifierProvider.notifier)
          .delete(tpl);
      if (mounted) {
        if (success) {
          WbSnackbar.showSuccess(context, 'Template deleted');
          Navigator.pop(context);
        } else {
          final error = ref.read(templateNotifierProvider).error;
          WbSnackbar.showError(context, error ?? 'Failed to delete template');
        }
      }
    }
  }
}

// ============ CATEGORY CHIP ============
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withAlpha(20)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withAlpha(40),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ TYPE CHIP (for variable dialog) ============
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withAlpha(20)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withAlpha(40),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
