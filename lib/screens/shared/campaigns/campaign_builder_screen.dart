import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../data/models/campaign/campaign_model.dart';
import '../../../data/models/template/template_model.dart';
import '../../../providers/campaigns/campaign_provider.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/contacts/contact_provider.dart';
import '../../../providers/templates/template_provider.dart';

/// 📊 CAMPAIGN BUILDER SCREEN — Create / Edit Campaign
class CampaignBuilderScreen extends ConsumerStatefulWidget {
  final CampaignModel? existingCampaign;

  const CampaignBuilderScreen({super.key, this.existingCampaign});

  @override
  ConsumerState<CampaignBuilderScreen> createState() =>
      _CampaignBuilderScreenState();
}

class _CampaignBuilderScreenState extends ConsumerState<CampaignBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _messageController;
  late final TextEditingController _tagsController;
  late String _messageType;

  // Template state
  TemplateModel? _selectedTemplate;
  String _variableSource = 'static'; // 'static' or 'csv'
  final Map<String, String> _staticVariableValues = {};
  final Map<String, TextEditingController> _varControllers = {};

  // Audience state
  final List<String> _selectedGroups = [];
  final List<String> _importedPhones = [];

  // CSV recipient data (phone + variable columns)
  final List<Map<String, String>> _recipientData = [];
  List<String> _csvColumns = [];

  bool get _isEditing => widget.existingCampaign != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCampaign;
    _nameController = TextEditingController(text: c?.name ?? '');
    _descController = TextEditingController(text: c?.description ?? '');
    _messageController = TextEditingController(text: c?.messageBody ?? '');
    _tagsController = TextEditingController(
      text: c?.audienceTags.join(', ') ?? '',
    );
    _messageType = c?.messageType ?? 'text';
    _variableSource = c?.variableSource ?? 'static';

    // Restore existing audience
    if (c != null) {
      _selectedGroups.addAll(c.audienceGroups);
      _importedPhones.addAll(c.audiencePhones);
      _recipientData.addAll(c.recipientData);

      // Restore static variable values
      if (c.staticVariableValues.isNotEmpty) {
        _staticVariableValues.addAll(c.staticVariableValues);
        for (final entry in c.staticVariableValues.entries) {
          _varControllers[entry.key] = TextEditingController(text: entry.value);
        }
      }

      // Restore selected template for editing
      if (c.messageType == 'template' && c.selectedTemplateId != null) {
        _restoreSelectedTemplate(c.selectedTemplateId!);
      }
    }
  }

  /// Restore template from provider when editing existing campaign
  void _restoreSelectedTemplate(String templateId) {
    // Use addPostFrameCallback to access ref after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final templatesAsync = ref.read(approvedTemplatesProvider);
      templatesAsync.whenData((templates) {
        final match = templates.where((t) => t.id == templateId).toList();
        if (match.isNotEmpty && mounted) {
          setState(() {
            _selectedTemplate = match.first;
            // Init variable controllers for restored template
            final vars = TemplateModel.extractVariables(match.first.body);
            for (final v in vars) {
              if (!_varControllers.containsKey(v)) {
                _varControllers[v] = TextEditingController(
                  text: _staticVariableValues[v] ?? '',
                );
              }
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _messageController.dispose();
    _tagsController.dispose();
    for (final c in _varControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalAudienceCount {
    if (_variableSource == 'csv' && _recipientData.isNotEmpty) {
      return _recipientData.length;
    }
    return _importedPhones.length;
  }

  /// Get detected variables from selected template
  List<String> get _templateVariables {
    if (_selectedTemplate == null) return [];
    return TemplateModel.extractVariables(_selectedTemplate!.body);
  }

  // ============ TEMPLATE PICKER ============
  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            // Use Consumer to reactively watch templates (fixes loading forever on first open)
            return Consumer(builder: (context, ref, _) {
            final approvedAsync = ref.watch(approvedTemplatesProvider);
            return approvedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (templates) {
                if (templates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No approved templates',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create templates first and wait for Meta approval.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.description, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Select Template (${templates.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: templates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final t = templates[index];
                          final vars = TemplateModel.extractVariables(t.body);
                          final isSelected = _selectedTemplate?.id == t.id;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTemplate = t;
                                _messageController.text = t.name;
                                // Init variable controllers
                                for (final v in vars) {
                                  if (!_varControllers.containsKey(v)) {
                                    _varControllers[v] = TextEditingController(
                                      text: _staticVariableValues[v] ?? '',
                                    );
                                  }
                                }
                              });
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withAlpha(15)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary.withAlpha(80)
                                      : Colors.grey.withAlpha(30),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      // Category badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: t.category == 'MARKETING'
                                              ? Colors.purple.withAlpha(20)
                                              : Colors.blue.withAlpha(20),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.category,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: t.category == 'MARKETING'
                                                ? Colors.purple
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Body preview
                                  Text(
                                    t.body,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (vars.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: vars.map((v) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppColors.primary.withAlpha(40)),
                                        ),
                                        child: Text(
                                          '{{$v}}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      )).toList(),
                                    ),
                                  ],
                                  if (t.languageCode.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '🌐 ${t.languageCode}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
            });  // close Consumer
          },
        );
      },
    );
  }

  // ============ ENHANCED CSV IMPORT ============
  Future<void> _importCsvForCampaign() async {
    try {
      if (!mounted) return;
      final hasVars = _templateVariables.isNotEmpty && _messageType == 'template';

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📥 Import CSV', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasVars
                    ? 'Upload CSV with phone numbers AND variable columns.'
                    : 'Upload CSV with contact phone numbers.',
                style: const TextStyle(color: Color(0xFF444444)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ phone (required)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (hasVars)
                      ...(_templateVariables.map((v) => Text(
                        '✅ $v (variable)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ))),
                    const Text('☐ Other columns optional', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                  ],
                ),
              ),
              if (hasVars) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CSV columns will be mapped to template variables automatically',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose File'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final csvString = await file.readAsString();

      // Parse CSV manually to get headers + data
      final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        if (mounted) WbSnackbar.showError(context, 'Empty CSV file');
        return;
      }

      // First line = headers
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();
      final phoneColIndex = headers.indexWhere(
        (h) => h == 'phone' || h == 'phone_number' || h == 'mobile' || h == 'number',
      );

      if (phoneColIndex == -1) {
        if (mounted) {
          WbSnackbar.showError(context, 'CSV must have a "phone" column');
        }
        return;
      }

      // Check which template variables are present in CSV
      final varColumnMap = <String, int>{}; // varName -> columnIndex
      for (final varName in _templateVariables) {
        final colIndex = headers.indexOf(varName.toLowerCase());
        if (colIndex != -1) {
          varColumnMap[varName] = colIndex;
        }
      }

      // Parse data rows
      final parsedRecipients = <Map<String, String>>[];
      final parsedPhones = <String>[];

      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim().replaceAll('"', '')).toList();
        if (cols.length <= phoneColIndex) continue;

        final phone = _normalizePhone(cols[phoneColIndex]);
        if (phone.isEmpty) continue;

        parsedPhones.add(phone);

        // Build recipient data with variables
        final row = <String, String>{'phone': phone};
        for (final entry in varColumnMap.entries) {
          if (entry.value < cols.length) {
            row[entry.key] = cols[entry.value];
          }
        }
        parsedRecipients.add(row);
      }

      if (parsedPhones.isEmpty) {
        if (mounted) WbSnackbar.showError(context, 'No valid contacts found in CSV');
        return;
      }

      setState(() {
        _csvColumns = varColumnMap.keys.toList();
        _recipientData.clear();
        _recipientData.addAll(parsedRecipients);
        _importedPhones.clear();
        _importedPhones.addAll(parsedPhones);

        // If template has variables and CSV has matching columns, switch to CSV mode
        if (varColumnMap.isNotEmpty && _messageType == 'template') {
          _variableSource = 'csv';
        }
      });

      if (mounted) {
        final varInfo = varColumnMap.isNotEmpty
            ? ' (${varColumnMap.length} variable columns detected)'
            : '';
        WbSnackbar.showSuccess(context, '${parsedPhones.length} contacts imported$varInfo');
      }
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, 'Import failed: ${e.toString()}');
    }
  }

  String _normalizePhone(String raw) {
    raw = raw.trim();

    // Handle Excel scientific notation (e.g. 9.23E+11 → 923000000000)
    if (RegExp(r'^[0-9.]+[eE][+\-]?[0-9]+$').hasMatch(raw)) {
      try {
        final n = double.parse(raw);
        raw = n.toStringAsFixed(0);
      } catch (_) {}
    }

    // Remove all non-digit chars except leading +
    raw = raw.startsWith('+')
        ? '+${raw.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}'
        : raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Already has + prefix and valid length
    if (raw.startsWith('+') && raw.length >= 12) return raw;
    // Pakistani local format: 03XXXXXXXXX → +92XXXXXXXXXX
    if (raw.startsWith('03') && raw.length == 11) {
      return '+92${raw.substring(1)}';
    }
    // Pakistani without leading 0: 3XXXXXXXXX (10 digits starting with 3) → +923XXXXXXXXX
    if (raw.startsWith('3') && raw.length == 10) {
      return '+92$raw';
    }
    // International without +: 923XXXXXXXXX → +923XXXXXXXXX
    if (raw.startsWith('92') && raw.length >= 12 && !raw.startsWith('+')) {
      return '+$raw';
    }
    // Plain digits (10+ digits, likely international without prefix)
    if (raw.length >= 10 && !raw.startsWith('+')) return '+$raw';
    return '';
  }

  // ============ SEND TEST MESSAGE ============
  Future<void> _sendTestMessage() async {
    final phoneController = TextEditingController();
    final testPhone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Test Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your phone number to receive a test message with the current campaign content.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+923001234567',
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, phoneController.text.trim()),
            child: const Text('Send Test'),
          ),
        ],
      ),
    );

    if (testPhone == null || testPhone.isEmpty || !mounted) return;

    final phone = _normalizePhone(testPhone);
    if (phone.isEmpty) {
      WbSnackbar.showError(context, 'Invalid phone number');
      return;
    }

    try {
      final waRepo = ref.read(whatsappRepositoryProvider);
      final userId = ref.read(userIdProvider);
      if (userId == null) return;

      if (_messageType == 'template' && _selectedTemplate != null) {
        // Send template message
        final params = <String, String>{};
        for (final entry in _varControllers.entries) {
          params[entry.key] = entry.value.text.isNotEmpty
              ? entry.value.text
              : 'TEST_${entry.key}';
        }
        // Build components in Meta API format
        final varValues = params.values.toList();
        List<Map<String, dynamic>>? components;
        if (varValues.isNotEmpty) {
          components = [
            {
              'type': 'body',
              'parameters': varValues.map((v) => <String, dynamic>{
                'type': 'text',
                'text': v,
              }).toList(),
            }
          ];
        }
        await waRepo.sendTemplate(
          userId: userId,
          to: phone,
          templateName: _selectedTemplate!.name,
          languageCode: _selectedTemplate!.languageCode,
          components: components,
        );
      } else {
        // Send text message
        final msg = _messageController.text.trim();
        if (msg.isEmpty) {
          if (mounted) WbSnackbar.showError(context, 'Enter a message first');
          return;
        }
        await waRepo.sendText(
          userId: userId,
          to: phone,
          message: '[TEST] $msg',
        );
      }

      if (mounted) {
        WbSnackbar.showSuccess(context, 'Test message sent to $phone');
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Test failed: ${e.toString()}');
      }
    }
  }

  // ============ SAVE ============
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_messageType == 'template' && _selectedTemplate == null) {
      WbSnackbar.showError(context, 'Please select a template');
      return;
    }

    // Validate audience
    final hasGroups = _selectedGroups.isNotEmpty;
    final hasPhones = _importedPhones.isNotEmpty;
    final hasCsvData = _recipientData.isNotEmpty;
    final hasTags = _tagsController.text.trim().isNotEmpty;
    if (!hasGroups && !hasPhones && !hasCsvData && !hasTags) {
      WbSnackbar.showError(context, 'Add at least one audience (CSV, groups, or tags)');
      return;
    }

    // Duplicate campaign name check (only for new campaigns)
    if (!_isEditing) {
      final campaigns = ref.read(campaignsProvider).valueOrNull ?? [];
      final name = _nameController.text.trim().toLowerCase();
      final duplicate = campaigns.any((c) => c.name.toLowerCase() == name);
      if (duplicate) {
        final proceed = await WbDialog.showConfirm(
          context,
          title: 'Duplicate Name',
          message: 'A campaign with this name already exists. Create anyway?',
        );
        if (!proceed) return;
      }
    }

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Collect static variable values from controllers
    for (final entry in _varControllers.entries) {
      _staticVariableValues[entry.key] = entry.value.text.trim();
    }

    final phones = _variableSource == 'csv' && _recipientData.isNotEmpty
        ? _recipientData.map((r) => r['phone'] ?? '').where((p) => p.isNotEmpty).toList()
        : _importedPhones;

    final campaign = CampaignModel(
      id: widget.existingCampaign?.id ?? '',
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      messageType: _messageType,
      messageBody: _messageType == 'template'
          ? (_selectedTemplate?.body ?? _messageController.text.trim())
          : _messageController.text.trim(),
      templateName: _messageType == 'template'
          ? (_selectedTemplate?.name ?? _messageController.text.trim())
          : null,
      templateLanguage: _messageType == 'template'
          ? (_selectedTemplate?.languageCode ?? 'en')
          : null,
      selectedTemplateId: _messageType == 'template' ? _selectedTemplate?.id : null,
      templateVariables: _messageType == 'template' ? _templateVariables : [],
      variableSource: _variableSource,
      staticVariableValues: _variableSource == 'static' ? _staticVariableValues : {},
      recipientData: _variableSource == 'csv' ? _recipientData : [],
      audiencePhones: phones,
      audienceTags: tags,
      audienceGroups: _selectedGroups,
      totalRecipients: phones.length,
      createdAt: widget.existingCampaign?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (_isEditing) {
      success = await ref.read(campaignNotifierProvider.notifier).update(campaign);
    } else {
      success = await ref.read(campaignNotifierProvider.notifier).create(campaign);
    }

    if (success && mounted) {
      // Show a visible success response before popping
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              Text(
                _isEditing ? 'Campaign Updated! ✅' : 'Campaign Created! 🚀',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isEditing
                    ? 'Your campaign has been updated successfully.'
                    : 'Your campaign is ready. Go to campaigns to start sending!',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      // Auto-dismiss after 1.5s and pop back
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(); // dismiss dialog
        context.pop(); // pop builder screen
      }
    } else if (mounted) {
      WbSnackbar.showError(
        context,
        ref.read(campaignNotifierProvider).error ?? 'Failed to save campaign',
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Campaign',
      message: 'Are you sure you want to delete this campaign?',
      isDanger: true,
    );

    if (!confirmed) return;

    final success = await ref
        .read(campaignNotifierProvider.notifier)
        .delete(widget.existingCampaign!.id);

    if (success && mounted) {
      WbSnackbar.showSuccess(context, 'Campaign deleted');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(campaignNotifierProvider);
    final groupsAsync = ref.watch(contactGroupsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Campaign' : 'New Campaign'),
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

              // ============ CAMPAIGN INFO ============
              Text(
                '📊 Campaign Info',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              WbTextField(
                label: 'Campaign Name',
                hint: 'e.g., Holiday Promo',
                controller: _nameController,
                prefixIcon: const Icon(Icons.campaign),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Description',
                hint: 'Campaign purpose...',
                controller: _descController,
                maxLines: 2,
                isRequired: false,
                prefixIcon: const Icon(Icons.description),
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: AppDimens.xl),

              // ============ MESSAGE TYPE ============
              Text(
                '💬 Message',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.sm),

              // Message type selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'text', label: Text('Text'), icon: Icon(Icons.chat)),
                  ButtonSegment(value: 'template', label: Text('Template'), icon: Icon(Icons.description)),
                ],
                selected: {_messageType},
                onSelectionChanged: (value) {
                  setState(() {
                    _messageType = value.first;
                    if (_messageType == 'text') {
                      _selectedTemplate = null;
                    }
                  });
                },
              ),
              const SizedBox(height: AppDimens.md),

              // -------- TEXT MODE --------
              if (_messageType == 'text')
                WbTextField(
                  label: 'Message Text',
                  hint: 'Type your message...',
                  controller: _messageController,
                  maxLines: 4,
                  prefixIcon: const Icon(Icons.chat),
                  textInputAction: TextInputAction.next,
                ),

              // -------- TEMPLATE MODE --------
              if (_messageType == 'template') ...[
                // Template picker button
                InkWell(
                  onTap: _showTemplatePicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedTemplate != null
                            ? AppColors.primary.withAlpha(80)
                            : Colors.grey.withAlpha(80),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedTemplate != null
                          ? AppColors.primary.withAlpha(8)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedTemplate != null
                              ? Icons.description
                              : Icons.add_circle_outline,
                          color: _selectedTemplate != null
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _selectedTemplate != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedTemplate!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedTemplate!.category} · ${_selectedTemplate!.languageCode}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Tap to select a template',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),

                // -------- TEMPLATE PREVIEW --------
                if (_selectedTemplate != null) ...[
                  const SizedBox(height: AppDimens.md),
                  _buildTemplatePreview(theme),

                  // -------- VARIABLES SECTION --------
                  if (_templateVariables.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.md),
                    _buildVariablesSection(theme),
                  ],
                ],
              ],

              const SizedBox(height: AppDimens.xl),

              // ============ AUDIENCE ============
              Row(
                children: [
                  Text(
                    '👥 Audience',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_totalAudienceCount > 0 || _selectedGroups.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedGroups.isNotEmpty
                            ? '$_totalAudienceCount direct + ${_selectedGroups.length} groups'
                            : '$_totalAudienceCount contacts',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.sm),

              // -------- Group Selection --------
              Text(
                'Select Contact Groups',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              groupsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('Error loading groups', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                data: (groups) {
                  if (groups.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No contact groups found. Add groups to contacts first.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: groups.map((group) {
                      final isSelected = _selectedGroups.contains(group);
                      return FilterChip(
                        label: Text(group),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withAlpha(30),
                        checkmarkColor: AppColors.primary,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedGroups.add(group);
                            } else {
                              _selectedGroups.remove(group);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: AppDimens.md),

              // -------- Import CSV (hide when variables section has its own CSV button) --------
              if (!(_messageType == 'template' && _templateVariables.isNotEmpty && _variableSource == 'csv')) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importCsvForCampaign,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(_messageType == 'template' && _templateVariables.isNotEmpty
                          ? 'Import CSV (Phone + Variables)'
                          : 'Import CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withAlpha(100)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_importedPhones.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _importedPhones.clear();
                          _recipientData.clear();
                          _csvColumns.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                      label: Text(
                        'Clear (${_importedPhones.length})',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              ],

              // Show imported data preview
              if (_importedPhones.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildImportPreview(theme),
              ],

              const SizedBox(height: AppDimens.xs),
              Text(
                'Select groups or import CSV to define your audience.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppDimens.xl),

              // Test message + Save buttons
              Row(
                children: [
                  // Send Test button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actionState.isLoading ? null : _sendTestMessage,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Send Test'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withAlpha(100)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save button
                  Expanded(
                    flex: 2,
                    child: WbButton(
                      text: _isEditing ? 'Update Campaign' : 'Create Campaign',
                      onPressed: _save,
                      isLoading: actionState.isLoading,
                      icon: Icons.save,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.lg),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TEMPLATE PREVIEW WIDGET ============
  Widget _buildTemplatePreview(ThemeData theme) {
    final t = _selectedTemplate!;
    final body = _getPreviewBody();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE7FFD4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE8B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Message Preview',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                if (t.header != null && t.header!.isNotEmpty) ...[
                  Text(
                    t.header!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Body
                Text(body, style: const TextStyle(fontSize: 13.5)),
                // Footer
                if (t.footer != null && t.footer!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.footer!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Template Buttons
          if (t.buttons.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.black.withAlpha(15),
            ),
            ...t.buttons.map((btn) {
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
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.black.withAlpha(10)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFF00A884)),
                    const SizedBox(width: 6),
                    Text(
                      text.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00A884),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _getPreviewBody() {
    var body = _selectedTemplate!.body;
    for (final varName in _templateVariables) {
      final value = _varControllers[varName]?.text ?? '';
      if (value.isNotEmpty) {
        body = body.replaceAll('{{$varName}}', value);
      }
    }
    return body;
  }

  // ============ VARIABLES SECTION ============
  Widget _buildVariablesSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Template Variables (${_templateVariables.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Variable source toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'static',
                label: Text('Same for all'),
                icon: Icon(Icons.edit, size: 16),
              ),
              ButtonSegment(
                value: 'csv',
                label: Text('From CSV'),
                icon: Icon(Icons.table_chart, size: 16),
              ),
            ],
            selected: {_variableSource},
            onSelectionChanged: (value) {
              setState(() => _variableSource = value.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Static mode: input fields for each variable
          if (_variableSource == 'static') ...[
            Text(
              'Enter values that will be used for all recipients:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            for (final varName in _templateVariables) ...[
              _buildVariableInput(varName, theme),
              const SizedBox(height: 8),
            ],
          ],

          // CSV mode
          if (_variableSource == 'csv') ...[
            if (_recipientData.isEmpty || _csvColumns.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(40)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.upload_file, size: 32, color: Colors.orange.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'Import a CSV file with variable columns',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Required columns: phone, ${_templateVariables.join(", ")}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _importCsvForCampaign,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Import CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Show mapped columns
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          '${_recipientData.length} recipients with ${_csvColumns.length} variable(s)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Column mapping preview
                    for (final col in _csvColumns) ...[
                      Row(
                        children: [
                          const SizedBox(width: 22),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CSV: $col',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '{{$col}}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Preview first 2 rows
                    if (_recipientData.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      Text(
                        'Sample: ${_recipientData.first.entries.where((e) => e.key != 'phone').map((e) => '${e.key}="${e.value}"').join(', ')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVariableInput(String varName, ThemeData theme) {
    if (!_varControllers.containsKey(varName)) {
      _varControllers[varName] = TextEditingController(
        text: _staticVariableValues[varName] ?? '',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Variable chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Text(
            '{{$varName}}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Input field
        SizedBox(
          height: 40,
          child: TextField(
            controller: _varControllers[varName],
            decoration: InputDecoration(
              hintText: 'Enter value for $varName',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              _staticVariableValues[varName] = val;
              setState(() {}); // Update preview
            },
          ),
        ),
      ],
    );
  }

  // ============ IMPORT PREVIEW ============
  Widget _buildImportPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📱 ${_importedPhones.length} contacts imported',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (_csvColumns.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${_csvColumns.length} vars',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _importedPhones.take(5).join(', ') +
                (_importedPhones.length > 5 ? ' ... +${_importedPhones.length - 5} more' : ''),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
