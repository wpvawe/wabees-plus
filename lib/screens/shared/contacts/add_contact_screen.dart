import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/utils/validators/phone_validator.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../providers/contacts/contact_provider.dart';

/// 📇 ADD / EDIT CONTACT SCREEN — Enhanced with Groups + Validation
class AddContactScreen extends ConsumerStatefulWidget {
  final ContactModel? existingContact;

  const AddContactScreen({super.key, this.existingContact});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;
  String? _selectedGroup;

  bool get _isEditing => widget.existingContact != null;

  static const _presetGroups = [
    'VIP',
    'Customers',
    'Leads',
    'Partners',
    'Support',
    'Uncategorized',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _nameController = TextEditingController(text: c?.name ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _companyController = TextEditingController(text: c?.company ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _tagsController = TextEditingController(text: c?.tags.join(', ') ?? '');
    _selectedGroup = c?.group;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text.trim().isEmpty
        ? <String>[]
        : _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).take(10).toList();

    final contact = ContactModel(
      id: widget.existingContact?.id ?? '',
      phone: _phoneController.text.trim(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      company: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      tags: tags,
      group: _selectedGroup,
      createdAt: widget.existingContact?.createdAt ?? DateTime.now(),
      totalMessages: widget.existingContact?.totalMessages ?? 0,
    );

    bool success;
    if (_isEditing) {
      success = await ref.read(contactNotifierProvider.notifier).update(contact);
    } else {
      success = await ref.read(contactNotifierProvider.notifier).create(contact);
    }

    if (success && mounted) {
      WbSnackbar.showSuccess(
        context,
        _isEditing ? 'Contact updated' : 'Contact added',
      );
      context.pop();
    } else if (mounted) {
      WbSnackbar.showError(context, ref.read(contactNotifierProvider).error ?? 'Failed');
    }
  }

  Future<void> _delete() async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Contact',
      message: 'Are you sure you want to delete this contact?',
    );

    if (confirmed != true) return;

    final success = await ref.read(contactNotifierProvider.notifier).delete(
      widget.existingContact!.id,
    );

    if (success && mounted) {
      WbSnackbar.showSuccess(context, 'Contact deleted');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(contactNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contact' : 'Add Contact'),
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

              WbTextField(
                label: 'Phone Number',
                hint: '+923001234567',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: PhoneValidator.validate,
                prefixIcon: const Icon(Icons.phone),
                enabled: !_isEditing,
                textInputAction: TextInputAction.next,
                maxLength: 20,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Name',
                hint: 'Contact name',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.trim().length > 100) {
                    return 'Name is too long (max 100 chars)';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                maxLength: 100,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Email',
                hint: 'Optional',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email),
                isRequired: false,
                textInputAction: TextInputAction.next,
                maxLength: 255,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Company',
                hint: 'Optional',
                controller: _companyController,
                prefixIcon: const Icon(Icons.business),
                isRequired: false,
                textInputAction: TextInputAction.next,
                maxLength: 100,
              ),
              const SizedBox(height: AppDimens.md),

              // Group Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedGroup,
                decoration: InputDecoration(
                  labelText: 'Group',
                  prefixIcon: const Icon(Icons.group_work),
                  hintText: 'Select group...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  contentPadding: AppDimens.inputPadding,
                ),
                items: _presetGroups.map((group) {
                  return DropdownMenuItem(
                    value: group,
                    child: Text(group),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedGroup = v),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Tags',
                hint: 'Comma separated: VIP, Customer, Lead',
                controller: _tagsController,
                prefixIcon: const Icon(Icons.label),
                isRequired: false,
                textInputAction: TextInputAction.next,
                maxLength: 200,
              ),
              const SizedBox(height: AppDimens.md),

              WbTextField(
                label: 'Notes',
                hint: 'Optional notes...',
                controller: _notesController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.note),
                isRequired: false,
                textInputAction: TextInputAction.done,
                maxLength: 500,
              ),
              const SizedBox(height: AppDimens.xl),

              WbButton(
                text: _isEditing ? 'Update Contact' : 'Save Contact',
                onPressed: _save,
                isLoading: actionState.isLoading,
                icon: Icons.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
