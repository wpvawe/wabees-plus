import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/buttons/wb_button.dart';
import '../../../core/widgets/inputs/wb_text_field.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';
import '../../../providers/auth/auth_provider.dart';

/// 🏢 BUSINESS PROFILE SCREEN
/// View and update WhatsApp Business Profile (about, description, email, address, websites, category)
class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _aboutController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  String _selectedVertical = '';
  bool _isSaving = false;
  bool _loaded = false;

  static const _verticals = [
    '', 'UNDEFINED', 'OTHER', 'AUTO', 'BEAUTY', 'APPAREL', 'EDU',
    'ENTERTAIN', 'EVENT_PLAN', 'FINANCE', 'GROCERY', 'GOVT',
    'HOTEL', 'HEALTH', 'NONPROFIT', 'PROF_SERVICES', 'RETAIL',
    'TRAVEL', 'RESTAURANT', 'NOT_A_BIZ',
  ];

  void _populateFields(Map<String, dynamic> profile) {
    if (_loaded) return;
    _loaded = true;
    _aboutController.text = profile['about'] ?? '';
    _descriptionController.text = profile['description'] ?? '';
    _emailController.text = profile['email'] ?? '';
    _addressController.text = profile['address'] ?? '';
    final websites = profile['websites'];
    if (websites is List && websites.isNotEmpty) {
      _websiteController.text = websites.first.toString();
    }
    _selectedVertical = profile['vertical'] ?? '';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final profileData = <String, dynamic>{};

      if (_aboutController.text.trim().isNotEmpty) {
        profileData['about'] = _aboutController.text.trim();
      }
      if (_descriptionController.text.trim().isNotEmpty) {
        profileData['description'] = _descriptionController.text.trim();
      }
      if (_emailController.text.trim().isNotEmpty) {
        profileData['email'] = _emailController.text.trim();
      }
      if (_addressController.text.trim().isNotEmpty) {
        profileData['address'] = _addressController.text.trim();
      }
      if (_websiteController.text.trim().isNotEmpty) {
        profileData['websites'] = [_websiteController.text.trim()];
      }
      if (_selectedVertical.isNotEmpty && _selectedVertical != 'UNDEFINED') {
        profileData['vertical'] = _selectedVertical;
      }

      final repo = ref.read(whatsappRepositoryProvider);
      final result = await repo.updateBusinessProfile(
        userId: user.id,
        profileData: profileData,
      );

      if (mounted) {
        if (result.success) {
          WbSnackbar.showSuccess(context, 'Business profile updated!');
          ref.invalidate(businessProfileProvider);
        } else {
          WbSnackbar.showError(context, result.message ?? 'Update failed');
        }
      }
    } catch (e) {
      if (mounted) {
        WbSnackbar.showError(context, 'Something went wrong: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _aboutController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const WbLoading(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          _populateFields(profile);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(businessProfileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppDimens.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture
                  if (profile['profile_picture_url'] != null &&
                      profile['profile_picture_url'].toString().isNotEmpty)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppDimens.lg),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(profile['profile_picture_url'].toString()),
                          backgroundColor: AppColors.primary.withAlpha(20),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppDimens.sm),

                  // About
                  WbTextField(
                    controller: _aboutController,
                    label: 'About',
                    hint: 'Brief description shown under your business name',
                    prefixIcon: const Icon(Icons.info_outline),
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: AppDimens.md),

                  // Description
                  WbTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Detailed description of your business',
                    prefixIcon: const Icon(Icons.description),
                    maxLines: 4,
                    isRequired: false,
                  ),
                  const SizedBox(height: AppDimens.md),

                  // Email
                  WbTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'contact@business.com',
                    prefixIcon: const Icon(Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    isRequired: false,
                  ),
                  const SizedBox(height: AppDimens.md),

                  // Address
                  WbTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Business address',
                    prefixIcon: const Icon(Icons.location_on),
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: AppDimens.md),

                  // Website
                  WbTextField(
                    controller: _websiteController,
                    label: 'Website',
                    hint: 'https://yourbusiness.com',
                    prefixIcon: const Icon(Icons.language),
                    keyboardType: TextInputType.url,
                    isRequired: false,
                  ),
                  const SizedBox(height: AppDimens.md),

                  // Category / Vertical
                  Text(
                    'Business Category',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withAlpha(60)),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _verticals.contains(_selectedVertical)
                            ? _selectedVertical
                            : '',
                        isExpanded: true,
                        items: _verticals.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              v.isEmpty ? 'Select category...' : _formatVertical(v),
                              style: TextStyle(
                                fontSize: 14,
                                color: v.isEmpty
                                    ? theme.colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedVertical = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimens.xl),

                  // Save button
                  WbButton(
                    text: 'Update Profile',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    icon: Icons.save,
                  ),
                  const SizedBox(height: AppDimens.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatVertical(String v) {
    return v.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}
