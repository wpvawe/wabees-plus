import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../data/models/template/template_model.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../providers/contacts/contact_provider.dart';
import '../../../providers/templates/template_provider.dart';

/// 📨 TEMPLATE SEND DIALOG — Apply template → fill variables → send
/// Shows as a bottom sheet with contact picker, variable inputs, live preview, send
class TemplateSendDialog extends ConsumerStatefulWidget {
  final TemplateModel template;

  const TemplateSendDialog({super.key, required this.template});

  /// Show the dialog as a modal bottom sheet
  static Future<bool?> show(BuildContext context, TemplateModel template) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
      ),
      builder: (_) => TemplateSendDialog(template: template),
    );
  }

  @override
  ConsumerState<TemplateSendDialog> createState() => _TemplateSendDialogState();
}

class _TemplateSendDialogState extends ConsumerState<TemplateSendDialog> {
  final _phoneController = TextEditingController();
  final _variableControllers = <TextEditingController>[];
  final _searchController = TextEditingController();
  ContactModel? _selectedContact;
  bool _isSending = false;
  String _searchQuery = '';

  TemplateModel get template => widget.template;

  @override
  void initState() {
    super.initState();
    // Create controllers for each variable in the template
    for (int i = 0; i < template.variables.length; i++) {
      final controller = TextEditingController();
      // Listen for changes to update preview in real-time
      controller.addListener(_onVariableChanged);
      _variableControllers.add(controller);
    }
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  void _onVariableChanged() {
    // Trigger rebuild so preview updates in real-time
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    for (final c in _variableControllers) {
      c.removeListener(_onVariableChanged);
      c.dispose();
    }
    super.dispose();
  }

  /// Get a user-friendly label for a variable
  String _getVariableLabel(String varName) {
    // If it's a numbered var like "1", "2", show it clearly
    if (RegExp(r'^\d+$').hasMatch(varName)) {
      return 'variable $varName';
    }
    // Named vars: replace underscores with spaces
    return varName.replaceAll('_', ' ');
  }

  Future<void> _send() async {
    final phone = _selectedContact?.phone ?? _phoneController.text.trim();
    if (phone.isEmpty) {
      WbSnackbar.showWarning(context, 'Please enter a phone number or select a contact');
      return;
    }

    // Build components for variables
    List<Map<String, dynamic>>? components;
    if (_variableControllers.isNotEmpty) {
      final params = _variableControllers.map((c) {
        return {'type': 'text', 'text': c.text.trim().isEmpty ? ' ' : c.text.trim()};
      }).toList();

      components = [
        {
          'type': 'body',
          'parameters': params,
        }
      ];
    }

    setState(() => _isSending = true);

    try {
      final notifier = ref.read(templateNotifierProvider.notifier);
      final result = await notifier.sendTemplate(
        to: phone,
        templateName: template.name,
        languageCode: template.languageCode,
        components: components,
      );

      if (mounted) {
        if (result) {
          WbSnackbar.showSuccess(context, 'Template sent to $phone');
          Navigator.pop(context, true);
        } else {
          final error = ref.read(templateNotifierProvider).error;
          WbSnackbar.showError(context, error ?? 'Failed to send template');
        }
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Failed to send: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(contactsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppDimens.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimens.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: const Icon(Icons.send, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Template',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          template.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppDimens.md),
                children: [
                  // ============ CONTACT PICKER ============
                  Text(
                    'Recipient',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.xs),

                  if (_selectedContact != null) ...[
                    _ContactChip(
                      contact: _selectedContact!,
                      onRemove: () => setState(() {
                        _selectedContact = null;
                        _phoneController.clear();
                      }),
                    ),
                  ] else ...[
                    WbTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: '+92300XXXXXXX',
                      prefixIcon: const Icon(Icons.phone),
                      keyboardType: TextInputType.phone,
                      isRequired: false,
                    ),
                    const SizedBox(height: AppDimens.xs),

                    // Contact search
                    WbTextField(
                      controller: _searchController,
                      label: 'Or pick from contacts',
                      hint: 'Search contacts...',
                      prefixIcon: const Icon(Icons.search),
                      isRequired: false,
                    ),
                    const SizedBox(height: AppDimens.xs),

                    // Contact list
                    contactsAsync.when(
                      data: (contacts) {
                        final filtered = _searchQuery.isEmpty
                            ? contacts.take(5).toList()
                            : contacts.where((c) {
                                final name = c.name.toLowerCase();
                                final phone = c.phone.toLowerCase();
                                return name.contains(_searchQuery) ||
                                    phone.contains(_searchQuery);
                              }).take(10).toList();

                        if (filtered.isEmpty) return const SizedBox.shrink();

                        return Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withAlpha(40),
                            ),
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final contact = filtered[i];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withAlpha(20),
                                  child: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(contact.name, style: const TextStyle(fontSize: 13)),
                                subtitle: Text(contact.phone, style: const TextStyle(fontSize: 11)),
                                onTap: () {
                                  setState(() {
                                    _selectedContact = contact;
                                    _phoneController.text = contact.phone;
                                    _searchController.clear();
                                  });
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppDimens.sm),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],

                  const SizedBox(height: AppDimens.lg),

                  // ============ VARIABLE INPUTS ============
                  if (_variableControllers.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.data_object, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Fill Template Variables',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter values below. The preview will update as you type.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: AppDimens.sm),
                    ...List.generate(_variableControllers.length, (i) {
                      final varName = i < template.variables.length
                          ? template.variables[i]
                          : '${i + 1}';
                      final displayLabel = _getVariableLabel(varName);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.sm),
                        child: WbTextField(
                          controller: _variableControllers[i],
                          label: displayLabel,
                          hint: 'Enter $displayLabel...',
                          prefixIcon: Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '{{${i + 1}}}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppDimens.sm),
                  ],

                  // ============ LIVE PREVIEW ============
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Message Preview',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_variableControllers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _allVariablesFilled
                                ? const Color(0xFF25D366).withAlpha(20)
                                : Colors.orange.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _allVariablesFilled ? '✓ Ready' : '$_filledCount/${_variableControllers.length} filled',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _allVariablesFilled ? const Color(0xFF25D366) : Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.xs),

                  // WhatsApp-style message bubble
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF8C6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(4),
                      ),
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
                        // Header
                        if (template.header != null && template.header!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Text(
                              template.header!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                        // Body with live variable substitution
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _buildRichPreview(theme),
                        ),

                        // Footer
                        if (template.footer != null && template.footer!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Text(
                              template.footer!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withAlpha(130),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        // Timestamp (decorative)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _formatNow(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black.withAlpha(100),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: Colors.black.withAlpha(100),
                              ),
                            ],
                          ),
                        ),

                        // Template Buttons
                        if (template.buttons.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            height: 1,
                            color: Colors.black.withAlpha(15),
                          ),
                          ...template.buttons.map((btn) {
                            final type = (btn['type'] ?? '').toString().toUpperCase();
                            final text = btn['text'] ?? 'Button';
                            IconData icon;
                            if (type == 'URL') {
                              icon = Icons.open_in_new;
                            } else if (type == 'PHONE_NUMBER') {
                              icon = Icons.phone;
                            } else if (type == 'QUICK_REPLY') {
                              icon = Icons.reply;
                            } else {
                              icon = Icons.touch_app;
                            }
                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(icon, size: 16, color: const Color(0xFF00A884)),
                                      const SizedBox(width: 6),
                                      Text(
                                        text.toString(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF00A884),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: Colors.black.withAlpha(10),
                                ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.lg),

                  // ============ SEND BUTTON ============
                  WbButton(
                    onPressed: _isSending ? null : _send,
                    text: 'Send Template Message',
                    isLoading: _isSending,
                    icon: Icons.send,
                  ),
                  const SizedBox(height: AppDimens.lg),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build rich preview text with highlighted unfilled variables
  Widget _buildRichPreview(ThemeData theme) {
    final body = template.body;
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    // Find all {{varName}} patterns and build TextSpans
    final regex = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');
    for (final match in regex.allMatches(body)) {
      // Add text before this variable
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: body.substring(lastEnd, match.start),
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ));
      }

      // Find the variable index
      final varName = match.group(1)!;
      final varIndex = template.variables.indexOf(varName);
      final value = (varIndex >= 0 && varIndex < _variableControllers.length)
          ? _variableControllers[varIndex].text.trim()
          : '';

      if (value.isNotEmpty) {
        // Filled: show the value in bold green
        spans.add(TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF075E54),
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ));
      } else {
        // Unfilled: show highlighted placeholder
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withAlpha(60), width: 0.5),
            ),
            child: Text(
              _getVariableLabel(varName),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ));
      }

      lastEnd = match.end;
    }

    // Add remaining text after last variable
    if (lastEnd < body.length) {
      spans.add(TextSpan(
        text: body.substring(lastEnd),
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
      ));
    }

    // If no variables found, just show the text
    if (spans.isEmpty) {
      return Text(
        body,
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }

  bool get _allVariablesFilled =>
      _variableControllers.every((c) => c.text.trim().isNotEmpty);

  int get _filledCount =>
      _variableControllers.where((c) => c.text.trim().isNotEmpty).length;

  String _formatNow() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

// ============ CONTACT CHIP ============
class _ContactChip extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onRemove;

  const _ContactChip({required this.contact, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  contact.phone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
