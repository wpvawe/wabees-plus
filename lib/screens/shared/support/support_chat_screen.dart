import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback/wb_snackbar.dart';
import '../../../data/models/support/support_message_model.dart';
import '../../../providers/support/support_provider.dart';

/// 💬 SUPPORT CHAT SCREEN — User ↔ Admin 1:1 chat
class SupportChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const SupportChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  String? _chatId;
  bool _initialMessageSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initChat();
  }

  Future<void> _initChat() async {
    final notifier = ref.read(supportNotifierProvider.notifier);
    final id = await notifier.ensureChat();
    if (mounted) {
      if (id != null) {
        setState(() => _chatId = id);
        notifier.setOnline(id, 'user', true);
        notifier.markAsRead(id, 'user');
        // Send initial message if provided (e.g., plan request)
        if (widget.initialMessage != null && !_initialMessageSent) {
          _initialMessageSent = true;
          await notifier.sendMessage(id, widget.initialMessage!);
        }
      } else {
        setState(() => _chatId = '__error__');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_chatId == null) return;
    final notifier = ref.read(supportNotifierProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      notifier.setOnline(_chatId!, 'user', true);
      notifier.markAsRead(_chatId!, 'user');
    } else {
      notifier.setOnline(_chatId!, 'user', false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_chatId != null) {
      ref.read(supportNotifierProvider.notifier).setOnline(_chatId!, 'user', false);
    }
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _chatId == null) return;

    _controller.clear();
    final success = await ref
        .read(supportNotifierProvider.notifier)
        .sendMessage(_chatId!, text);

    if (!success && mounted) {
      final error = ref.read(supportNotifierProvider).error;
      WbSnackbar.showError(context, error ?? 'Failed to send');
    }
  }

  Future<void> _pickImage() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (xFile == null || _chatId == null) return;

    final success = await ref
        .read(supportNotifierProvider.notifier)
        .sendImage(_chatId!, File(xFile.path));

    if (!success && mounted) {
      final error = ref.read(supportNotifierProvider).error;
      WbSnackbar.showError(context, error ?? 'Failed to send image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatAsync = ref.watch(userSupportChatProvider);
    final actionState = ref.watch(supportNotifierProvider);

    final isAdminOnline = chatAsync.valueOrNull?.adminOnline ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Support Chat', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAdminOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isAdminOnline ? 'Admin Online' : 'Admin Offline',
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
      body: _chatId == null
          ? const Center(child: CircularProgressIndicator())
          : _chatId == '__error__'
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('Could not load support chat'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() => _chatId = null);
                          _initChat();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                // Messages list
                Expanded(child: _buildMessageList()),

                // Character counter + rate limit
                if (_controller.text.length > 800)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${_controller.text.length}/1000',
                      style: TextStyle(
                        fontSize: 11,
                        color: _controller.text.length > 1000
                            ? Colors.red
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                // Input bar
                _buildInputBar(theme, actionState),
              ],
            ),
    );
  }

  Widget _buildMessageList() {
    if (_chatId == null) return const SizedBox.shrink();

    final messagesAsync = ref.watch(supportMessagesProvider(_chatId!));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        _scrollToBottom();

        // Mark as read when messages arrive
        if (messages.isNotEmpty) {
          ref.read(supportNotifierProvider.notifier).markAsRead(_chatId!, 'user');
        }

        if (messages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent, size: 64, color: AppColors.primary),
                SizedBox(height: 16),
                Text('Welcome to Support!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Send a message to get started. Our admin team will respond shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (ctx, i) {
            final msg = messages[i];
            final isMe = msg.isFromUser;
            final showDate = i == 0 ||
                _isDifferentDay(messages[i - 1].createdAt, msg.createdAt);

            return Column(
              children: [
                if (showDate) _DateSeparator(date: msg.createdAt),
                _MessageBubble(message: msg, isMe: isMe),
              ],
            );
          },
        );
      },
    );
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Widget _buildInputBar(ThemeData theme, SupportActionState actionState) {
    return Container(
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
            // Image picker
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppColors.primary),
              onPressed: actionState.isSending ? null : _pickImage,
            ),

            // Text input
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: 1000,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onTap: () => _focusNode.requestFocus(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  counterText: '',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Send button
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: actionState.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: actionState.isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ MESSAGE BUBBLE ============
class _MessageBubble extends StatelessWidget {
  final SupportMessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
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
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image
            if (message.isImage && message.imageUrl != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, message.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(message.imageUrl!),
                ),
              ),


            if (message.isImage && message.body != '📷 Image')
              const SizedBox(height: 6),

            // Text
            if (!message.isImage || message.body != '📷 Image')
              SelectableText(
                message.body,
                style: theme.textTheme.bodyMedium,
              ),

            const SizedBox(height: 4),

            // Time + read status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

// ============ DATE SEPARATOR ============
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
