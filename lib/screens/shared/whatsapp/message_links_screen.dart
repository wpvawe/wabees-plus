import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../providers/whatsapp/whatsapp_provider.dart';

/// 🔗 MESSAGE LINKS SCREEN — Create & manage wa.me message links
class MessageLinksScreen extends ConsumerStatefulWidget {
  const MessageLinksScreen({super.key});

  @override
  ConsumerState<MessageLinksScreen> createState() => _MessageLinksScreenState();
}

class _MessageLinksScreenState extends ConsumerState<MessageLinksScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _createLink() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prefilled message')),
      );
      return;
    }

    final notifier = ref.read(messageLinksNotifierProvider.notifier);
    final success = await notifier.createLink(message);

    if (success && mounted) {
      _messageController.clear();
      ref.invalidate(messageLinksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message link created! ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      final error = ref.read(messageLinksNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteLink(String linkId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Link?'),
        content: const Text('This will permanently delete this message link.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(messageLinksNotifierProvider.notifier);
    final success = await notifier.deleteLink(linkId);

    if (success && mounted) {
      ref.invalidate(messageLinksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link deleted'), backgroundColor: Colors.orange),
      );
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied! 📋'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final linksAsync = ref.watch(messageLinksProvider);
    final notifierState = ref.watch(messageLinksNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Links'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(messageLinksProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ============ CREATE NEW LINK ============
          Container(
            margin: const EdgeInsets.all(AppDimens.md),
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outline.withAlpha(30)
                    : theme.colorScheme.outline.withAlpha(20),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_link_rounded, size: 18, color: Color(0xFF25D366)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Message Link',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sm),
                Text(
                  'Create a wa.me link with a prefilled message. Customers clicking this link will open WhatsApp with your message ready to send.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Hello! I need help with...',
                    labelText: 'Prefilled Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.md,
                      vertical: AppDimens.sm,
                    ),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppDimens.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: notifierState.isLoading ? null : _createLink,
                    icon: notifierState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_rounded, size: 18),
                    label: Text(notifierState.isLoading ? 'Creating...' : 'Create Link'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============ EXISTING LINKS ============
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Row(
              children: [
                Text(
                  'Your Message Links',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                linksAsync.when(
                  data: (links) => Text(
                    '${links.length} links',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.sm),

          Expanded(
            child: linksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 8),
                    Text('Failed to load links', style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => ref.invalidate(messageLinksProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (links) {
                if (links.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
                        const SizedBox(height: AppDimens.md),
                        Text(
                          'No message links yet',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create your first link above',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  itemCount: links.length,
                  itemBuilder: (context, index) {
                    final link = links[index];
                    final deepLink = link['deep_link_url'] ?? '';
                    final message = link['prefilled_message'] ?? '';
                    final code = link['code'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppDimens.sm),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHigh
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha(isDark ? 30 : 20),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.md,
                          vertical: AppDimens.xs,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withAlpha(15),
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          ),
                          child: const Icon(Icons.link_rounded, color: Color(0xFF25D366), size: 20),
                        ),
                        title: Text(
                          deepLink,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _copyLink(deepLink),
                              tooltip: 'Copy Link',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _deleteLink(code),
                              tooltip: 'Delete',
                            ),
                          ],
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
