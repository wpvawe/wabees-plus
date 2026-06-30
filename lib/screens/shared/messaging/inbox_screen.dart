import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/display/wb_avatar.dart';
import '../../../core/widgets/feedback/wb_loading.dart';
import '../../../core/widgets/wb_empty_state.dart';
import '../../../core/router/route_names.dart';
import '../../../providers/auth/auth_provider.dart';
import '../../../providers/messaging/messaging_provider.dart';
import '../../../data/models/message/conversation_model.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../providers/contacts/contact_provider.dart';

/// 📨 INBOX SCREEN — Conversation List
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _deletedConversations = {};
  _InboxFilter _activeFilter = _InboxFilter.none;
  String? _selectedTag;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final tagsAsync = ref.watch(userTagsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(RouteNames.dashboard),
        ),
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(RouteNames.newMessage),
            icon: const Icon(Icons.edit_square),
            tooltip: 'New Message',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filters
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: AppDimens.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Unread', Icons.mark_email_unread_outlined, _InboxFilter.allUnread, AppColors.warning),
                      const SizedBox(width: 6),
                      _buildFilterChip('Free Chat', Icons.access_time, _InboxFilter.freeChat, AppColors.info),
                      const SizedBox(width: 6),
                      _buildFilterChip('Free Unread', Icons.priority_high, _InboxFilter.freeUnread, const Color(0xFFE91E63)),
                      const SizedBox(width: 6),
                      // Tag filters
                      ...tagsAsync.when(
                        loading: () => <Widget>[],
                        error: (_, __) => <Widget>[],
                        data: (tags) => tags.map((tag) {
                          final tagName = tag['name'] ?? '';
                          final tagColor = _parseTagColor(tag['color']);
                          final isSelected = _selectedTag == tagName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(tagName),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTag = selected ? tagName : null;
                                  if (selected) _activeFilter = _InboxFilter.none;
                                });
                              },
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              selectedColor: tagColor.withAlpha(40),
                              labelStyle: TextStyle(
                                color: isSelected ? tagColor : Theme.of(context).colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? tagColor : Colors.transparent),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conversation List
          Expanded(
            child: conversationsAsync.when(
              loading: () => const WbLoading(message: 'Loading conversations...'),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (conversations) {
                // Apply filters
                final filtered = conversations.where((c) {
                  if (_deletedConversations.contains(c.contactPhone)) return false;
                  
                  final isFree = c.lastIncomingMessageAt != null && c.isReplyWindowOpen;
                  final isUnread = c.unreadCount > 0;

                  switch (_activeFilter) {
                    case _InboxFilter.allUnread:
                      if (!isUnread) return false;
                    case _InboxFilter.freeChat:
                      if (!isFree) return false;
                    case _InboxFilter.freeUnread:
                      if (!isFree || !isUnread) return false;
                    case _InboxFilter.none:
                      break;
                  }

                  // Tag filter
                  if (_selectedTag != null && !c.tags.contains(_selectedTag)) return false;

                  if (_searchQuery.isEmpty) return true;
                  return c.contactName.toLowerCase().contains(_searchQuery) ||
                         c.contactPhone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return WbEmptyState(
                    message: _searchQuery.isEmpty
                        ? 'No conversations yet'
                        : 'No results found',
                    icon: Icons.chat_bubble_outline,
                    actionText: _searchQuery.isEmpty ? 'Send a Message' : null,
                    onAction: _searchQuery.isEmpty
                        ? () => context.pushNamed(RouteNames.newMessage)
                        : null,
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    return Dismissible(
                      key: Key('conv_${conv.contactPhone}_${conv.lastMessageAt.millisecondsSinceEpoch}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: const Text('Delete Conversation', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600)),
                            content: Text('Delete conversation with ${conv.contactName}? All messages will be removed from your side.', style: const TextStyle(color: Color(0xFF444444))),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666)))),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (_) {
                        // Immediately update local state to satisfy Dismissible requirements
                        // This prevents "Dismissible widget is still part of the tree" error
                        setState(() {
                          _deletedConversations.add(conv.contactPhone);
                        });

                        final user = ref.read(currentUserProvider);
                        if (user != null) {
                          final ownerId = user.dataOwner ?? user.id;
                          ref.read(messageRepositoryProvider).deleteConversation(ownerId, conv.contactPhone);
                        }
                      },
                      child: _ConversationTile(
                        conversation: conv,
                        onTap: () {
                          context.pushNamed(
                            RouteNames.chat,
                            pathParameters: {'phone': conv.contactPhone},
                            extra: conv.contactName,
                          );
                        },
                        onLongPress: () => _showConvContextMenu(context, ref, conv),
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

  void _showConvContextMenu(BuildContext context, WidgetRef ref, ConversationModel conv) {
    final repo = ref.read(messageRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ownerId = user.dataOwner ?? user.id;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(conv.contactName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primary),
              title: Text(conv.isPinned ? 'Unpin Conversation' : 'Pin Conversation'),
              subtitle: conv.isPinned ? null : const Text('Max 3 pinned conversations'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await repo.togglePin(ownerId, conv.contactPhone);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maximum 3 conversations can be pinned')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline, color: AppColors.primary),
              title: const Text('Manage Tags'),
              onTap: () {
                Navigator.pop(ctx);
                _showTagDialog(context, ref, conv);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTagDialog(BuildContext context, WidgetRef ref, ConversationModel conv) {
    final repo = ref.read(messageRepositoryProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ownerId = user.dataOwner ?? user.id;
    final newTagController = TextEditingController();
    Color selectedColor = const Color(0xFF4CAF50);

    const tagColors = [
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF5722),
      Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF009688),
      Color(0xFFE91E63), Color(0xFF607D8B), Color(0xFF795548),
      Color(0xFF3F51B5),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final tagsAsync = ref.watch(userTagsProvider);
            // Watch conversation detail so tags update in real-time when toggled
            final convAsync = ref.watch(conversationDetailProvider(PhoneUtils.normalize(conv.contactPhone)));
            final currentTags = convAsync.valueOrNull?.tags ?? conv.tags;
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.label, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(child: Text('Manage Tags')),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTagController,
                            decoration: const InputDecoration(
                              hintText: 'New tag name...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary),
                          onPressed: () {
                            final name = newTagController.text.trim();
                            if (name.isNotEmpty) {
                              final hex = '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              repo.createTag(ownerId, name, hex);
                              newTagController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (ctx, setColorState) {
                        return Wrap(
                          spacing: 6,
                          children: tagColors.map((c) {
                            final isSelected = c == selectedColor;
                            return GestureDetector(
                              onTap: () => setColorState(() => selectedColor = c),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                  boxShadow: isSelected ? [BoxShadow(color: c.withAlpha(120), blurRadius: 6)] : null,
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    tagsAsync.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (tags) {
                        if (tags.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No tags yet. Create one above!', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView(
                            shrinkWrap: true,
                            children: tags.map((tag) {
                              final tagName = tag['name'] ?? '';
                              final tagColor = _parseTagColor(tag['color']);
                              final isApplied = currentTags.contains(tagName);
                              return CheckboxListTile(
                                title: Row(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tagName)),
                                  ],
                                ),
                                value: isApplied,
                                fillColor: WidgetStateProperty.resolveWith((states) =>
                                  states.contains(WidgetState.selected) ? tagColor : null),
                                dense: true,
                                secondary: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Tag'),
                                        content: Text('Delete "$tagName"? It will be removed from all conversations.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) repo.deleteTag(ownerId, tag['id']);
                                  },
                                ),
                                onChanged: (checked) {
                                  if (checked == true) {
                                    repo.addTag(ownerId, conv.contactPhone, tagName);
                                  } else {
                                    repo.removeTag(ownerId, conv.contactPhone, tagName);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }

  Color _parseTagColor(dynamic colorValue) {
    if (colorValue == null) return AppColors.primary;
    if (colorValue is String && colorValue.startsWith('#') && colorValue.length >= 7) {
      try {
        return Color(int.parse('FF${colorValue.substring(1)}', radix: 16));
      } catch (_) {
        return AppColors.primary;
      }
    }
    return AppColors.primary;
  }

  Widget _buildFilterChip(String label, IconData icon, _InboxFilter filter, Color color) {
    final isSelected = _activeFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _activeFilter = selected ? filter : _InboxFilter.none;
          if (selected) _selectedTag = null;
        });
      },
      avatar: Icon(isSelected ? Icons.check : icon, size: 18, color: isSelected ? color : null),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: color.withAlpha(40),
      labelStyle: TextStyle(
        color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : Colors.transparent),
      ),
    );
  }
}

// ============ CONVERSATION TILE ============
class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasUnread = conversation.unreadCount > 0;
    final canFreeReply =
        conversation.lastIncomingMessageAt != null && conversation.isReplyWindowOpen;
    
    // Resolve display name: saved contact name > WhatsApp profile name > phone
    final nameMap = ref.watch(contactNameMapProvider);
    final rawName = conversation.contactName;
    final phone = conversation.contactPhone;
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final isPhoneName = rawName == phone || rawName == phoneDigits || rawName.replaceAll(RegExp(r'[^0-9]'), '') == phoneDigits;
    final displayName = isPhoneName ? (nameMap[phoneDigits] ?? nameMap['+$phoneDigits'] ?? rawName) : rawName;
    
    final tagsAsync = ref.watch(userTagsProvider);
    // Build a map of tag name -> color from user's tags
    final tagColorMap = <String, Color>{};
    tagsAsync.whenData((tags) {
      for (final t in tags) {
        final name = t['name'] ?? '';
        final colorStr = t['color'];
        if (colorStr is String && colorStr.startsWith('#') && colorStr.length >= 7) {
          try {
            tagColorMap[name] = Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
          } catch (_) {
            tagColorMap[name] = AppColors.primary;
          }
        } else {
          tagColorMap[name] = AppColors.primary;
        }
      }
    });

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: WbAvatar(
        name: displayName,
        imageUrl: conversation.profileImageUrl,
        size: AppDimens.avatarMd,
      ),
      title: Row(
        children: [
          if (conversation.isBlocked) ...[
            const Icon(Icons.block_rounded, size: 14, color: Colors.red),
            const SizedBox(width: 4),
          ],
          if (conversation.isPinned) ...[
            Icon(Icons.push_pin, size: 14, color: AppColors.primary.withAlpha(180)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              displayName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation.lastMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasUnread
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (conversation.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: conversation.tags.take(3).map((tagName) {
                final color = tagColorMap[tagName] ?? AppColors.primary;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(80)),
                  ),
                  child: Text(
                    tagName,
                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(conversation.lastMessageAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: hasUnread
                  ? AppColors.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (canFreeReply) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(AppDimens.radiusCircle),
              ),
              child: Text(
                'Free',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xxs,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

enum _InboxFilter { none, allUnread, freeChat, freeUnread }
