import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/contact_import_export.dart';
import '../../../core/widgets/display/wb_avatar.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_dialog.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/contacts/contact_provider.dart';
import '../../../data/models/contact/contact_model.dart';

/// 📇 CONTACTS LIST SCREEN — Multi-Select, Groups, Import/Export
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroup;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete ${_selectedIds.length} Contacts',
      message: 'Are you sure you want to delete ${_selectedIds.length} contacts? This cannot be undone.',
    );

    if (confirmed != true || !mounted) return;

    final count = await ref.read(contactNotifierProvider.notifier).deleteMultiple(
      _selectedIds.toList(),
    );

    if (mounted) {
      WbSnackbar.showSuccess(context, '$count contacts deleted');
      _exitSelectionMode();
    }
  }

  Future<void> _deleteContact(ContactModel contact) async {
    final confirmed = await WbDialog.showConfirm(
      context,
      title: 'Delete Contact',
      message: 'Delete ${contact.displayName}?',
    );

    if (confirmed != true || !mounted) return;

    final success = await ref.read(contactNotifierProvider.notifier).delete(contact.id);

    if (success && mounted) {
      WbSnackbar.showSuccess(context, '${contact.displayName} deleted');
    }
  }

  Future<void> _importCsv() async {
    try {
      // Show import guide dialog first
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('📥 Import Contacts', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload a CSV file with these columns:', style: TextStyle(color: Color(0xFF444444))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ Phone (required)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E), fontSize: 13)),
                    Text('✅ Name (required)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E), fontSize: 13)),
                    Text('☐ Email (optional)', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    Text('☐ Company (optional)', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    Text('☐ Group (optional)', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    Text('☐ Tags (optional, ; separated)', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    Text('☐ Notes (optional)', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('💡 Phone formats accepted:', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.w500)),
              const Text('+923001234567, 03001234567, 923001234567', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Duplicates will be automatically skipped.', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666)))),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx, false);
                await _downloadSample();
              },
              child: const Text('📄 Download Sample', style: TextStyle(color: Color(0xFF128C7E))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              child: const Text('Choose File', style: TextStyle(color: Colors.white)),
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

      final contacts = ContactCsvHelper.importFromCsv(csvString);

      if (contacts.isEmpty) {
        if (mounted) {
          WbSnackbar.showError(context, 'No valid contacts found. Check the file format.');
        }
        return;
      }

      // Confirm import with count
      if (!mounted) return;
      final confirmed = await WbDialog.showConfirm(
        context,
        title: 'Import ${contacts.length} Contacts',
        message: 'Found ${contacts.length} valid contacts. Duplicates will be skipped. Import now?',
      );

      if (confirmed != true || !mounted) return;

      final count = await ref.read(contactNotifierProvider.notifier).importContacts(contacts);

      if (mounted) {
        WbSnackbar.showSuccess(context, '$count contacts imported successfully!');
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Import failed: ${e.toString()}');
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final contacts = await ref.read(contactNotifierProvider.notifier).exportContacts();

      if (contacts.isEmpty) {
        if (mounted) WbSnackbar.showError(context, 'No contacts to export');
        return;
      }

      final bytes = ContactCsvHelper.exportToBytes(contacts);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use native save dialog — user sees the file in their chosen location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Contacts Export',
        fileName: 'wabees_contacts_$timestamp.csv',
        bytes: bytes,
      );

      if (result != null && mounted) {
        WbSnackbar.showSuccess(context, '${contacts.length} contacts exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Export failed: ${e.toString()}');
      }
    }
  }

  Future<void> _downloadSample() async {
    try {
      final bytes = ContactCsvHelper.generateSampleCsvBytes();

      // Use native save dialog
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample CSV',
        fileName: 'wabees_contacts_sample.csv',
        bytes: bytes,
      );

      if (result != null && mounted) {
        WbSnackbar.showSuccess(context, 'Sample CSV saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Failed to save sample: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final groupsAsync = ref.watch(contactGroupsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close),
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete Selected',
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.goNamed(RouteNames.dashboard),
              ),
              title: const Text('Contacts'),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'add':
                        context.pushNamed(RouteNames.addContact);
                        break;
                      case 'import':
                        _importCsv();
                        break;
                      case 'export':
                        _exportCsv();
                        break;
                      case 'sample':
                        _downloadSample();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.person_add), title: Text('Add Contact'), dense: true)),
                    const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Import Contacts'), dense: true)),
                    const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.download), title: Text('Export Contacts'), dense: true)),
                    const PopupMenuItem(value: 'sample', child: ListTile(leading: Icon(Icons.description), title: Text('Download Sample CSV'), dense: true)),
                  ],
                ),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.pushNamed(RouteNames.addContact),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.xs,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                contentPadding: AppDimens.inputPadding,
              ),
            ),
          ),

          // Group Filter Chips
          groupsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (groups) {
              if (groups.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _selectedGroup == null,
                        onSelected: (_) => setState(() => _selectedGroup = null),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        selectedColor: AppColors.primary.withAlpha(30),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedGroup == null ? AppColors.primary : null,
                          fontWeight: _selectedGroup == null ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ...groups.map((group) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(group),
                        selected: _selectedGroup == group,
                        onSelected: (_) => setState(() {
                          _selectedGroup = _selectedGroup == group ? null : group;
                        }),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        selectedColor: AppColors.primary.withAlpha(30),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedGroup == group ? AppColors.primary : null,
                          fontWeight: _selectedGroup == group ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                    )),
                  ],
                ),
              );
            },
          ),

          // Contact Count Badge
          contactsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (contacts) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: AppDimens.xxs,
              ),
              child: Row(
                children: [
                  Text(
                    '${contacts.length} contacts',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedGroup != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '• Filtered by: $_selectedGroup',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Contacts List
          Expanded(
            child: contactsAsync.when(
              loading: () => const WbLoading(message: 'Loading contacts...'),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (contacts) {
                var filtered = contacts;

                // Apply group filter
                if (_selectedGroup != null) {
                  filtered = filtered
                      .where((c) => c.group == _selectedGroup)
                      .toList();
                }

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((c) =>
                      c.name.toLowerCase().contains(_searchQuery) ||
                      c.phone.contains(_searchQuery) ||
                      (c.company?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (c.group?.toLowerCase().contains(_searchQuery) ?? false) ||
                      c.tags.any((t) => t.toLowerCase().contains(_searchQuery)))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return WbEmptyState(
                    message: _searchQuery.isNotEmpty
                        ? 'No results found'
                        : _selectedGroup != null
                            ? 'No contacts in "$_selectedGroup"'
                            : 'No contacts yet',
                    icon: Icons.people_outline,
                    actionText: _searchQuery.isEmpty && _selectedGroup == null
                        ? 'Add Contact'
                        : null,
                    onAction: _searchQuery.isEmpty && _selectedGroup == null
                        ? () => context.pushNamed(RouteNames.addContact)
                        : null,
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final isSelected = _selectedIds.contains(contact.id);

                    return Dismissible(
                      key: ValueKey(contact.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteContact(contact);
                        return false; // We handle deletion manually
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade400,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(contact.id),
                                fillColor: WidgetStateProperty.resolveWith((states) =>
                                    states.contains(WidgetState.selected) ? AppColors.primary : null),
                              )
                            : WbAvatar(
                                name: contact.displayName,
                                imageUrl: contact.profileImageUrl,
                                size: AppDimens.avatarMd,
                              ),
                        title: Text(
                          contact.displayName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.phone,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (contact.group != null && contact.group!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  contact.groupLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (contact.tags.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                ),
                                child: Text(
                                  contact.tags.first,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20,
                                color: theme.colorScheme.onSurfaceVariant),
                              tooltip: 'Edit',
                              onPressed: () => context.pushNamed(
                                RouteNames.addContact,
                                extra: contact,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20,
                                color: Colors.redAccent),
                              tooltip: 'Delete',
                              onPressed: () => _deleteContact(contact),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                        onTap: _isSelectionMode
                            ? () => _toggleSelection(contact.id)
                            : () {
                                context.pushNamed(
                                  RouteNames.addContact,
                                  extra: contact,
                                );
                              },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedIds.add(contact.id);
                            });
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                          vertical: AppDimens.xxs,
                        ),
                      ),
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
}
