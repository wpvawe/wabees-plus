import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../data/models/support/support_chat_model.dart';
import '../../../data/models/support/support_message_model.dart';
import '../../../providers/support/support_provider.dart';
import '../../../providers/auth/auth_provider.dart';

/// 🛡️ ADMIN SUPPORT SCREEN — View all user chats & reply
class AdminSupportScreen extends ConsumerWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(adminSupportChatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Support Chats')),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No support chats yet',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (ctx, i) {
              final chat = chats[i];
              return _ChatTile(chat: chat);
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final SupportChatModel chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = chat.unreadCountAdmin > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withAlpha(25),
        child: Text(
          chat.userName.isNotEmpty ? chat.userName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.userName.isNotEmpty ? chat.userName : chat.userId,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (chat.userOnline)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage.isNotEmpty ? chat.lastMessage : 'No messages',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          color: hasUnread
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (chat.lastMessageAt != null)
            Text(
              _formatTime(chat.lastMessageAt!),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? AppColors.primary : Colors.grey,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chat.unreadCountAdmin}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdminChatDetail(chat: chat),
        ));
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ============ ADMIN CHAT DETAIL (per-user) ============
class AdminChatDetail extends ConsumerStatefulWidget {
  final SupportChatModel chat;

  const AdminChatDetail({super.key, required this.chat});

  @override
  ConsumerState<AdminChatDetail> createState() => _AdminChatDetailState();
}

class _AdminChatDetailState extends ConsumerState<AdminChatDetail>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _markRead();
  }

  void _setOnline(bool online) {
    ref.read(supportRepositoryProvider).setOnlineStatus(
          widget.chat.id, 'admin', online);
  }

  void _markRead() {
    ref.read(supportRepositoryProvider).markAsRead(widget.chat.id, 'admin');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
      _markRead();
    } else {
      _setOnline(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(
            chatId: widget.chat.id,
            senderId: user?.id ?? 'admin',
            senderRole: 'admin',
            body: text,
          );
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, e.toString());
    }
  }

  Future<void> _pickImage() async {
    final xFile =
        await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (xFile == null) return;

    final user = ref.read(currentUserProvider);
    try {
      await ref.read(supportRepositoryProvider).sendImage(
            chatId: widget.chat.id,
            senderId: user?.id ?? 'admin',
            senderRole: 'admin',
            imageFile: File(xFile.path),
          );
    } catch (e) {
      if (mounted) WbSnackbar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(supportMessagesProvider(widget.chat.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chat.userName, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.chat.userOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.chat.userOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                _scrollToBottom();
                _markRead();

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg.isFromAdmin;
                    return _AdminBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 1000,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Reply...',
                        counterText: '',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBubble extends StatelessWidget {
  final SupportMessageModel message;
  final bool isMe;

  const _AdminBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4, bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withAlpha(20)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.isImage && message.imageUrl != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, message.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(message.imageUrl!),
                ),
              ),
            if (!message.isImage || message.body != '📷 Image')
              SelectableText(message.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Smart image widget: local file path → Image.file, URL → Image.network
  Widget _buildImageWidget(String imageUrl) {
    final isLocal = !imageUrl.startsWith('http');
    if (isLocal) {
      final file = File(imageUrl);
      return Image.file(
        file,
        width: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 200, height: 150,
          child: Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    }
    return Image.network(
      imageUrl,
      width: 200,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: 200, height: 150,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 200, height: 150,
        child: Center(child: Icon(Icons.broken_image, size: 32)),
      ),
    );
  }

  /// Fullscreen image viewer with pinch-to-zoom
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final isLocal = !imageUrl.startsWith('http');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: isLocal
                  ? Image.file(File(imageUrl), fit: BoxFit.contain)
                  : Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
